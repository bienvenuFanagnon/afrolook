// Catalogue des templates « prêts à poster » du Studio : chaque template arrive déjà rempli
// (photo d'exemple, sur-titre, titre, texte de souhait, badge, effet) ; la personne remplace ce qu'elle veut.

import 'package:flutter/material.dart';

import '../../../models/post_widget.dart';
import 'collage_template.dart' show kCollageTemplateIds;
import 'story_script.dart' show kCreditsTemplateIds, kStoryTemplateIds;

/// Filtres du moteur de visage posés par un modèle (Android seulement : l'avatar et l'effet de bouche se règlent à la caméra, avant de filmer).
class TemplateFace {
  const TemplateFace({this.avatar, this.magic, this.gesture});

  /// Clé d'un avatar (`dragon`, `cat`…), libellé d'un effet magique (« Feu », « Cœurs »…) et geste qui le déclenche (`mouth`, `smile`…).
  final String? avatar;
  final String? magic;
  final String? gesture;
  bool get isEmpty => avatar == null && magic == null;
}

enum MontageCat { situations, emotions, insta, music, culture, fetes, finannee, vie, ambiances, pensees, weekend, evenements, droles }

extension MontageCatX on MontageCat {
  String get label => switch (this) {
        MontageCat.situations => '😂 Situations',
        MontageCat.emotions => '💫 Émotions',
        MontageCat.insta => '📸 Insta',
        MontageCat.music => '🎵 Musique',
        MontageCat.culture => '🌍 Culture',
        MontageCat.fetes => '🎊 Fêtes',
        MontageCat.finannee => '🎬 Fin d’année',
        MontageCat.vie => '🌱 Ma vie',
        MontageCat.ambiances => '🖤 Ambiances',
        MontageCat.pensees => '💭 Pensées',
        MontageCat.weekend => '🍹 Weekend',
        MontageCat.evenements => '📅 Événements',
        MontageCat.droles => '🤣 Drôles',
      };
}

enum MontageFx { none, money, hearts, coins, rain, storm, cloud, sparkle, fire, rays, speed, bokeh, zzz, leaves, crown, waves, disco, sunset, fireworks, moon, snow, confetti, ring, baby }

enum MontageFont { bold, anton, script }

enum MontagePos { top, center, bottom }

enum MontageFrame { none, wax, gold }

/// Éléments que la personne peut retirer du montage. Le filigrane « Créé sur Afrolook » n'en fait pas partie : il reste toujours.
enum MontageLayer { kick, title, wish, chip, brand, pseudo, stats, followers, fx, frame, tint, flag }

extension MontageLayerX on MontageLayer {
  String get label => switch (this) {
        MontageLayer.kick => 'Sur-titre',
        MontageLayer.title => 'Titre',
        MontageLayer.wish => 'Texte',
        MontageLayer.chip => 'Badge',
        MontageLayer.brand => 'Logo Afrolook',
        MontageLayer.pseudo => '@pseudo',
        MontageLayer.stats => 'J’aime · commentaires',
        MontageLayer.followers => 'Abonnés',
        MontageLayer.fx => 'Effet animé',
        MontageLayer.frame => 'Cadre',
        MontageLayer.tint => 'Teinte',
        MontageLayer.flag => 'Drapeau',
      };
}

class MontageTemplate {
  final String id;
  final MontageCat cat;
  final String name;

  /// Photo d'exemple (assets du projet) affichée tant que la personne n'a pas mis la sienne.
  final String sample;
  final bool sampleIsVideo;

  /// Réglages de la photo/vidéo : saturation (1 = normal) et luminosité (-0.5..0.5).
  final double saturation;
  final double brightness;
  final List<Color> tint;
  final List<double>? tintStops;
  final MontageFx fx;
  final MontageFrame frame;
  final MontagePos pos;
  final String kick;
  final String title;
  final MontageFont font;
  final bool longTitle;
  final Color accent;
  final String? chip;
  final String sound;
  final List<String> texts;

  /// Template « pays » : drapeau choisi parmi tous les pays du monde.
  final bool country;
  final String defaultCountry;

  /// Indépendance / fête nationale : titre, date et textes calculés selon le pays.
  final bool indep;

  /// Deux photos côte à côte (Fiancé·e) : photo d'exemple de la 2e moitié.
  final String? dualSample;

  /// Zone ronde pour une 2e photo (Nouveau parent).
  final bool baby;

  /// Widgets de publication posés d'office par le modèle (compte à rebours, lieu, WhatsApp…) : la personne les modifie, les déplace, en ajoute ou les retire (jusqu'à 5 par post).
  /// Une fonction, pour que les dates (« dans 14 jours ») soient calculées au moment où la personne ouvre le modèle.
  final List<PostWidget> Function()? presetWidgets;

  /// Modèle de créateur : sa musique est celle de la recette (null = aucune), et non celle du catalogue.
  final String? musicId;
  final bool musicOverridden;

  /// Filtres de visage de ce modèle (avatar, effet de bouche) : la caméra s'ouvre avec eux déjà choisis. Android seulement ; ailleurs le modèle n'est pas proposé.
  final TemplateFace? face;

  const MontageTemplate({
    required this.id,
    required this.cat,
    required this.name,
    required this.sample,
    this.sampleIsVideo = false,
    this.saturation = 1,
    this.brightness = 0,
    required this.tint,
    this.tintStops,
    this.fx = MontageFx.none,
    this.frame = MontageFrame.none,
    this.pos = MontagePos.bottom,
    this.kick = '',
    this.title = '',
    this.font = MontageFont.bold,
    this.longTitle = false,
    required this.accent,
    this.chip,
    this.sound = '',
    this.texts = const [],
    this.country = false,
    this.defaultCountry = 'TG',
    this.indep = false,
    this.dualSample,
    this.baby = false,
    this.presetWidgets,
    this.musicId,
    this.musicOverridden = false,
    this.face,
  });

  /// Un modèle de créateur : ce modèle du catalogue avec les textes, la musique et les widgets de la recette (identifiant propre).
  MontageTemplate derive({required String id, required String name, String? kick, String? title, String? chip, List<String>? texts, String? musicId, List<PostWidget> Function()? presetWidgets, TemplateFace? face}) => MontageTemplate(
        id: id, cat: cat, name: name, sample: sample, sampleIsVideo: sampleIsVideo, saturation: saturation, brightness: brightness, tint: tint, tintStops: tintStops,
        fx: fx, frame: frame, pos: pos, kick: kick ?? this.kick, title: title ?? this.title, font: font, longTitle: longTitle, accent: accent, chip: chip ?? this.chip,
        sound: sound, texts: texts ?? this.texts, country: country, defaultCountry: defaultCountry, indep: indep, dualSample: dualSample, baby: baby,
        presetWidgets: presetWidgets, musicId: musicId, musicOverridden: true, face: face ?? this.face,
      );

  /// Le modèle se fait en vidéo (vidéo d'exemple, ou filtres de visage filmés à la caméra) : son aperçu, une image de l'application, porte l'icône vidéo.
  bool get showsVideo => sampleIsVideo || face != null || isStory || isCredits || duoLayout != null;

  /// Modèle « générique de fin de film » : le texte monte lentement sur des photos qui changent (« Le film de mon année »).
  bool get isCredits => kCreditsTemplateIds.contains(id);

  /// Modèle « histoire » : une vidéo qui défile toute seule, scène après scène (voir `story_script.dart`).
  bool get isStory => kStoryTemplateIds.contains(id);

  /// Modèle récent (créé le 09/11/2026) : mis en avant partout (onglet « Nouveautés », bande de « Que créer ? », pastille « Nouveau ») pendant 30 jours.
  bool get isNew => DateTime.now().isBefore(kNewUntil) && (kNewTemplateIds.contains(id) || kNewTemplateCats.contains(cat));

  /// Modèle « duo » : DEUX vidéos (ou une vidéo et une image) l'une sur l'autre ou côte à côte ; null = pas un duo. La personne choisit sa vidéo, puis la 2e, dans l'éditeur.
  String? get duoLayout => kDuoLayouts[id];

  /// Modèle « collage » : 2 à 5 photos dans une mise en page, avec étiquettes et titre (voir `collage_template.dart`).
  bool get isCollage => kCollageTemplateIds.contains(id);

  bool get usesPrenom => texts.any((t) => t.contains('{prenom}'));

  /// Musique gratuite proposée d'office (modifiable ou retirable dans l'éditeur).
  String? get music => musicOverridden ? musicId : (kTemplateMusicLibre[id] ?? kTemplateMusic[id]);

  /// Chiffres d'exemple affichés tant que la personne n'a pas écrit les siens (j'aime, commentaires).
  (int, int) get sampleStats {
    var h = 0;
    for (final c in id.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return (1200 + h % 8800, 60 + (h ~/ 7) % 840);
  }
  bool get canUseVideo => dualSample == null;
}

const _p1 = 'assets/images/intro1.jpg';
const _p2 = 'assets/images/intro2.jpg';
const _p3 = 'assets/images/intro3.jpg';
const _p4 = 'assets/images/intro4.jpg';
const _p5 = 'assets/images/intro5.jpg';
const _p6 = 'assets/images/intro6.jpg';
const _p7 = 'assets/images/intro7.jpg';
const kMontageSampleVideo = 'assets/videos/intro_video.mp4';

Color _a(int r, int g, int b, double o) => Color.fromRGBO(r, g, b, o);
/// « L'année qui arrive » : à partir de septembre c'est l'année suivante (fin d'année : « Bonne année 2027 » dès l'automne 2026) ; de janvier à août, c'est l'année en cours (le 2 janvier 2027, « Bonne année 2027 », pas 2028).
/// Les nouveautés du 09/11/2026 : les modèles créés ce jour-là restent « nouveaux » jusqu'à cette date.
final DateTime kNewUntil = DateTime(2026, 12, 9);
const Set<MontageCat> kNewTemplateCats = {MontageCat.finannee, MontageCat.vie, MontageCat.ambiances, MontageCat.pensees, MontageCat.weekend, MontageCat.evenements, MontageCat.droles};
const Set<String> kNewTemplateIds = {'dragon_feu', 'anniv_minuteur', 'evenement'};

/// Modèles « duo » du catalogue : identifiant -> disposition des deux vidéos (`tb` = haut / bas, `sbs` = côte à côte).
const Map<String, String> kDuoLayouts = {'duo_reaction': 'tb', 'duo_cote': 'sbs', 'duo_avant_apres_video': 'sbs'};

final int _nextYear = DateTime.now().month >= 9 ? DateTime.now().year + 1 : DateTime.now().year;
/// L'année qui finit : à partir de septembre, l'année en cours ; de janvier à août, l'année qui vient de finir (« Merci 2026 » reste vrai en janvier 2027).
final int _endingYear = _nextYear - 1;

/// Minuit du 31 décembre de l'année qui finit (heure de l'appareil, en UTC) : l'échéance du compte à rebours des modèles de fin d'année.
String _newYearEve() => DateTime(_endingYear, 12, 31, 23, 59, 59).toUtc().toIso8601String();

/// Date ISO (UTC) dans [days] jours à [hour] h (heure de l'appareil) : l'échéance d'office d'un compte à rebours de modèle.
String montageInDays(int days, int hour) {
  final d = DateTime.now().add(Duration(days: days));
  return DateTime(d.year, d.month, d.day, hour).toUtc().toIso8601String();
}

/// « Ma vidéo avec ce son » : aucun habillage, la vidéo de la personne et la musique seule (son d'origine coupé par défaut).
/// Volontairement absent de la galerie : on y arrive depuis la page Musique ou la page d'un titre.
const kPlainTemplateId = 'plain';
final MontageTemplate kPlainTemplate = MontageTemplate(
  id: kPlainTemplateId,
  cat: MontageCat.insta,
  name: 'Ma vidéo avec ce son',
  sample: _p4,
  tint: const [Color(0x00000000), Color(0x00000000)],
  accent: const Color(0xFFFFFFFF),
);

final List<MontageTemplate> kMontageTemplates = [
  // ── Situations ──
  MontageTemplate(id: 'fauche', cat: MontageCat.situations, name: 'Fauché(e) — fin de mois', sample: _p7, saturation: .55,
      tint: [_a(0, 0, 0, .15), _a(0, 0, 0, .7)], fx: MontageFx.money, kick: 'Fin du mois', title: 'Le compte pleure 💸',
      accent: const Color(0xFFFFD400), chip: '🪙 Solde : 0 pièce', sound: 'Coupé-décalé « fin du mois »',
      texts: ['Le 30 est encore loin… courage à tous ceux qui comptent les jours 🙏', 'Mon solde et moi, on ne se parle plus depuis le 15 😭', 'Si tu me vois sourire, c’est que le salaire est tombé 😅']),
  MontageTemplate(id: 'amour', cat: MontageCat.situations, name: 'Amoureux(se)', sample: _p6,
      tint: [_a(255, 60, 120, .12), _a(120, 0, 40, .62)], fx: MontageFx.hearts, kick: 'Mon cœur', title: 'Toi & moi', font: MontageFont.script,
      accent: const Color(0xFFFFB3C7), chip: '🎁 Offre-lui un cadeau', sound: 'Love song afro',
      texts: ['Chaque jour avec toi est un cadeau ❤️', 'Tu es ma plus belle histoire, {prenom} 💕', 'Mon cœur a choisi, et il ne regrette rien 😍']),
  MontageTemplate(id: 'boss', cat: MontageCat.situations, name: 'Plein d’argent — Boss Mode', sample: _p2,
      tint: [_a(255, 200, 0, .1), _a(60, 40, 0, .72)], fx: MontageFx.coins, frame: MontageFrame.gold, kick: 'Boss mode', title: 'On est riches 🤑', font: MontageFont.anton,
      accent: const Color(0xFFFFD400), chip: '🪙 +12 500 pièces gagnées', sound: 'Afro trap',
      texts: ['Le travail paie, la patience aussi 💼', 'Pas de bruit, juste des résultats 🤫💰', 'Mes gains Afrolook ont parlé ce mois-ci 🚀']),
  MontageTemplate(id: 'separation', cat: MontageCat.situations, name: 'Séparation (pluie)', sample: _p1, saturation: .5, brightness: -.08,
      tint: [_a(40, 70, 140, .45), _a(5, 10, 30, .78)], fx: MontageFx.rain, pos: MontagePos.center, kick: 'C’est fini', title: 'On s’est perdus 💔',
      accent: const Color(0xFF9EC5FF), sound: 'Piano triste',
      texts: ['Certaines histoires s’arrêtent pour que d’autres commencent 🌧️', 'J’ai donné mon cœur, on me l’a rendu en morceaux 💔', 'La pluie passera. Je vais bien… bientôt 🌦️']),
  MontageTemplate(id: 'celib', cat: MontageCat.situations, name: 'Célibataire & heureux(se)', sample: _p3,
      tint: [_a(255, 120, 180, .05), _a(80, 0, 60, .58)], fx: MontageFx.sparkle, kick: 'Statut', title: 'Célibataire & heureux(se) 😎', longTitle: true,
      accent: const Color(0xFFFFD400), chip: '💚 Statut : célibataire', sound: 'Amapiano',
      texts: ['Célibataire, pas désespéré(e) 😎', 'Je me suis choisi(e) en premier, et ça me va très bien ✨', 'Mon seul crush : mes objectifs 🎯']),
  MontageTemplate(id: 'goumin', cat: MontageCat.situations, name: 'Goumin', sample: _p5, saturation: .8,
      tint: [_a(0, 0, 0, .35), _a(60, 0, 0, .72)], fx: MontageFx.storm, kick: 'Aujourd’hui', title: 'J’ai goumin 😤', font: MontageFont.anton,
      accent: const Color(0xFFFF6B5B), sound: 'Zouglou lent',
      texts: ['Laissez-moi avec mon goumin ce soir 😤', 'Goumin a frappé fort, mais demain ça ira 💪', 'Pas d’humeur, pas de blagues, juste du goumin 😶']),
  MontageTemplate(id: 'justebien', cat: MontageCat.situations, name: 'Juste bien', sample: _p4,
      tint: [_a(0, 0, 0, 0), _a(40, 30, 20, .62)], kick: 'Ça va', title: 'Juste bien 😐',
      accent: const Color(0xFFF2DFC0), sound: 'Kora calme',
      texts: ['Ni trop, ni trop peu. Juste bien 😐', 'Pas de drame aujourd’hui, et c’est déjà beaucoup 🙂', 'Je ne me plains pas, je respire 🌿']),
  MontageTemplate(id: 'fiance', cat: MontageCat.situations, name: 'Fiancé(e) — 2 photos', sample: _p2, dualSample: _p6,
      tint: [_a(0, 0, 0, 0), _a(40, 0, 30, .78)], tintStops: const [.4, 1], fx: MontageFx.ring, kick: 'Elle a dit oui', title: 'Fiancés 💍', font: MontageFont.script,
      accent: const Color(0xFFFFE6A8), chip: '💍 Nouveau statut', sound: 'Mariage afro',
      texts: ['Elle a dit OUI ! 💍 Le plus beau jour de ma vie', 'Bientôt Monsieur & Madame 💕', '{prenom} & moi, pour la vie 💍']),
  MontageTemplate(id: 'parent', cat: MontageCat.situations, name: 'Nouveau parent', sample: _p5, baby: true,
      tint: [_a(255, 240, 200, .05), _a(60, 40, 0, .62)], fx: MontageFx.baby, kick: 'Nouveau parent', title: 'Bienvenue bébé 👶', font: MontageFont.script,
      accent: const Color(0xFFFFE08A), sound: 'Berceuse kora',
      texts: ['Bienvenue au monde, {prenom} 👶 Tu es notre plus belle bénédiction', 'Parent depuis aujourd’hui. Cœur plein, nuits courtes 🍼', 'Le plus petit membre de la famille est arrivé 💛']),
  // ── Émotions ──
  MontageTemplate(id: 'enfeu', cat: MontageCat.emotions, name: 'En feu', sample: _p6,
      tint: [_a(0, 0, 0, .2), _a(80, 0, 0, .5)], fx: MontageFx.fire, pos: MontagePos.top, kick: 'Aujourd’hui', title: 'En feu 🔥', font: MontageFont.anton,
      accent: const Color(0xFFFFB13B), chip: '🔥 Série : 12 jours', sound: 'Afrobeat énergique',
      texts: ['Personne ne peut m’arrêter aujourd’hui 🔥', 'Énergie à 200 %, laissez passer 🚀', 'Je brille, je brûle, je fonce 🔥']),
  MontageTemplate(id: 'goodvibes', cat: MontageCat.emotions, name: 'Good Vibes', sample: _p3,
      tint: [_a(255, 220, 100, .15), _a(120, 40, 80, .52)], fx: MontageFx.rays, kick: 'Mood', title: 'Good Vibes ✨', font: MontageFont.script,
      accent: const Color(0xFFFFE27A), sound: 'Highlife joyeux',
      texts: ['Que des bonnes ondes ici ✨', 'Je garde le sourire, c’est gratuit 😁', 'Positivité activée, négativité bloquée 🚫']),
  MontageTemplate(id: 'enforme', cat: MontageCat.emotions, name: 'En forme', sample: _p2, saturation: 1.15,
      tint: [_a(0, 0, 0, 0), _a(0, 40, 20, .68)], fx: MontageFx.speed, kick: 'Séance du jour ✅', title: 'En forme 💪', font: MontageFont.anton,
      accent: const Color(0xFF2ECC71), chip: '💪 Jour 21/30', sound: 'Afro workout',
      texts: ['Corps sain, esprit sain 💪', 'Une séance de plus, une excuse de moins 🏃🏾', 'La discipline bat la motivation 🔥']),
  MontageTemplate(id: 'humeur', cat: MontageCat.emotions, name: 'Bonne humeur', sample: _p4,
      tint: [_a(255, 220, 80, .12), _a(120, 60, 0, .58)], fx: MontageFx.bokeh, kick: 'Humeur du jour', title: 'Bonne humeur 😊',
      accent: const Color(0xFFFFD400), sound: 'Coupé-décalé',
      texts: ['Aujourd’hui, je choisis la joie 😊', 'Rien ne gâchera ma journée 🌞', 'Souris, la vie est belle 😁']),
  MontageTemplate(id: 'pasforme', cat: MontageCat.emotions, name: 'Pas en forme', sample: _p7, saturation: .4, brightness: -.05,
      tint: [_a(60, 70, 90, .35), _a(20, 25, 35, .78)], fx: MontageFx.cloud, kick: 'Humeur du jour', title: 'Pas en forme 🌧️',
      accent: const Color(0xFFB8C4D9), sound: 'Guitare douce',
      texts: ['Pas trop la forme aujourd’hui… pensez à moi 🌧️', 'Journée grise, mais ça va passer 🙏', 'Batterie faible, besoin de repos 🛌🏾']),
  MontageTemplate(id: 'epuise', cat: MontageCat.emotions, name: 'Épuisé(e)', sample: _p1, saturation: .6, brightness: -.08,
      tint: [_a(30, 20, 80, .35), _a(10, 5, 30, .78)], fx: MontageFx.zzz, kick: 'Batterie faible', title: 'Épuisé(e) 💤',
      accent: const Color(0xFFB9A7FF), chip: '🔋 2 %', sound: 'Ambiance nuit',
      texts: ['Je dors debout 💤', 'Ne me demandez rien avant demain 😴', 'Mode avion activé ✈️💤']),
  MontageTemplate(id: 'zen', cat: MontageCat.emotions, name: 'Mode Zen', sample: _p5,
      tint: [_a(120, 255, 190, .08), _a(0, 50, 40, .68)], fx: MontageFx.leaves, kick: 'Mode zen', title: 'Respire 🧘', font: MontageFont.script,
      accent: const Color(0xFFA7F3D0), sound: 'Kora méditation',
      texts: ['Respire. Tout ira bien 🧘', 'Je protège ma paix 🍃', 'Calme, centré(e), aligné(e) ✨']),
  MontageTemplate(id: 'queen', cat: MontageCat.emotions, name: 'Queen Mode', sample: _p1,
      tint: [_a(80, 0, 120, .15), _a(40, 0, 60, .72)], fx: MontageFx.crown, frame: MontageFrame.gold, kick: 'Queen mode', title: 'Queen 👑', font: MontageFont.anton,
      accent: const Color(0xFFFFD400), sound: 'Afropop',
      texts: ['Ajuste ta couronne et avance 👑', 'Reine de mon royaume 👑✨', 'Je ne rivalise pas, je règne 💅🏾']),
  // ── Culture ──
  MontageTemplate(id: 'pays', cat: MontageCat.culture, name: 'Fier(e) de mon pays', sample: _p2, country: true, defaultCountry: 'CI',
      tint: [_a(0, 0, 0, 0), _a(0, 0, 0, .72)], tintStops: const [.45, 1], fx: MontageFx.sparkle, kick: 'Fier(e) de mon pays', title: '{pays}', longTitle: true,
      accent: Colors.white, sound: 'Hymne afro instrumental',
      texts: ['{pays} dans le cœur, partout où je vais 🌍', 'Mes racines, ma force : {pays} 💪', 'Fier(e) de mes origines ❤️']),
  MontageTemplate(id: 'marche', cat: MontageCat.culture, name: 'Marché africain', sample: _p4,
      tint: [_a(0, 0, 0, 0), _a(60, 20, 0, .72)], tintStops: const [.4, 1], frame: MontageFrame.wax, kick: 'Ambiance', title: 'Au marché 🛒', font: MontageFont.anton,
      accent: const Color(0xFFF5A623), sound: 'Ambiance marché',
      texts: ['Journée marché ! Qui veut quoi ? 🛒', 'Les meilleurs prix sont au marché 😄', 'Couleurs, odeurs, ambiance : mon marché 🧺']),
  MontageTemplate(id: 'plage', cat: MontageCat.culture, name: 'Plage côte Atlantique', sample: _p3,
      tint: [_a(80, 200, 255, .14), _a(0, 60, 90, .55)], fx: MontageFx.waves, pos: MontagePos.top, kick: 'Côte atlantique', title: 'À la plage 🌊', font: MontageFont.script,
      accent: const Color(0xFF7FE7FF), sound: 'Vagues + guitare',
      texts: ['Les pieds dans le sable, la tête ailleurs 🌊', 'Week-end à la plage, téléphone en mode avion 🏖️', 'Vue sur l’Atlantique, cœur en paix 🌅']),
  MontageTemplate(id: 'afrobeat', cat: MontageCat.culture, name: 'Boîte de nuit Afrobeat', sample: kMontageSampleVideo, sampleIsVideo: true,
      tint: [_a(60, 0, 90, .35), _a(10, 0, 30, .72)], fx: MontageFx.disco, kick: 'Ce soir', title: 'Afrobeat Night 🎶', font: MontageFont.anton,
      accent: const Color(0xFFFF4FD8), chip: '🎵 Son Afrolook', sound: 'Afrobeat club',
      texts: ['Ce soir on danse jusqu’au matin 🎶', 'Le DJ a mis mon son, je ne réponds plus 💃🏾', 'Afrobeat dans les veines 🔥']),
  MontageTemplate(id: 'savane', cat: MontageCat.culture, name: 'Savane au coucher', sample: _p2, saturation: 1.2,
      tint: [_a(255, 140, 40, .35), _a(90, 20, 60, .5)], fx: MontageFx.sunset, pos: MontagePos.top, kick: 'Heure dorée', title: 'Savane au coucher 🌅', longTitle: true,
      accent: const Color(0xFFFFD28A), sound: 'Djembé lointain',
      texts: ['Quand le soleil se couche sur la savane… 🌅', 'Afrique, ma terre, ma lumière 🦒', 'Heure dorée, âme apaisée ✨']),
  // ── Fêtes ──
  MontageTemplate(id: 'indep', cat: MontageCat.fetes, name: 'Indépendance / Fête nationale', sample: _p1, country: true, indep: true,
      tint: [_a(0, 0, 0, 0), _a(0, 0, 0, .75)], tintStops: const [.4, 1], fx: MontageFx.fireworks, longTitle: true,
      accent: const Color(0xFFFFD400), sound: 'Fanfare festive'),
  MontageTemplate(id: 'nouvelan', cat: MontageCat.fetes, name: 'Nouvel An', sample: kMontageSampleVideo, sampleIsVideo: true,
      tint: [_a(0, 0, 40, .35), _a(0, 0, 20, .72)], fx: MontageFx.fireworks, kick: '31 déc. → 1er janv.', title: 'Bonne année $_nextYear 🎆', font: MontageFont.anton,
      accent: const Color(0xFFFFD400), sound: 'Compte à rebours festif',
      texts: ['Bonne et heureuse année $_nextYear ! Santé, paix et réussite 🎆', 'Nouvelle année, nouveaux objectifs, même énergie 🚀', 'Que $_nextYear t’apporte tout ce que ton cœur désire ✨']),
  MontageTemplate(id: 'ramadan', cat: MontageCat.fetes, name: 'Ramadan / Aïd', sample: _p5,
      tint: [_a(10, 20, 70, .55), _a(5, 10, 40, .78)], fx: MontageFx.moon, kick: 'Mois béni', title: 'Ramadan Moubarak 🌙', font: MontageFont.script, longTitle: true,
      accent: const Color(0xFFFFE7A3), sound: 'Oud doux',
      texts: ['Ramadan Moubarak à toute la famille 🌙', 'Que ce mois béni t’apporte paix et bénédictions ✨', 'Aïd Moubarak ! Que vos prières soient exaucées 🤲🏾']),
  MontageTemplate(id: 'noel', cat: MontageCat.fetes, name: 'Noël', sample: _p3,
      tint: [_a(0, 60, 30, .25), _a(80, 0, 0, .62)], fx: MontageFx.snow, kick: '25 décembre', title: 'Joyeux Noël 🎄', font: MontageFont.script,
      accent: const Color(0xFFFFD400), sound: 'Chant de Noël afro',
      texts: ['Joyeux Noël à tous ceux que j’aime 🎄', 'Que la magie de Noël remplisse ta maison de joie ✨', 'Paix, amour et bons plats : c’est Noël 🎁']),
  MontageTemplate(id: 'valentin', cat: MontageCat.fetes, name: 'Saint-Valentin', sample: _p6,
      tint: [_a(255, 0, 80, .1), _a(90, 0, 30, .66)], fx: MontageFx.hearts, kick: '14 février', title: 'Saint-Valentin 💝', font: MontageFont.script,
      accent: const Color(0xFFFFB3C7), chip: '🎁 Envoie un cadeau', sound: 'Love song afro',
      texts: ['Joyeuse Saint-Valentin, mon amour 💝', 'Tu es mon plus beau cadeau ❤️', 'En couple ou pas : aime-toi d’abord 💕']),
  MontageTemplate(id: 'anniv', cat: MontageCat.fetes, name: 'Anniversaire', sample: _p4,
      tint: [_a(0, 0, 0, 0), _a(60, 0, 80, .62)], fx: MontageFx.confetti, kick: 'Aujourd’hui', title: 'Joyeux anniversaire 🎂', longTitle: true,
      accent: const Color(0xFFFFD400), chip: '🎁 Offre-moi un cadeau', sound: 'Joyeux anniversaire afro',
      texts: ['Joyeux anniversaire {prenom} ! Que Dieu te garde 🎂', 'Un an de plus, une bénédiction de plus 🎉', 'C’est mon anniversaire ! Vos vœux me font plaisir 🥳']),
  // Filtres de visage : la caméra s'ouvre avec l'avatar et l'effet de bouche déjà choisis (Android seulement : le modèle n'est pas proposé ailleurs).
  MontageTemplate(id: 'dragon_feu', cat: MontageCat.situations, name: 'Dragon qui crache le feu', sample: _p5, saturation: 1.1,
      tint: [_a(60, 10, 0, .1), _a(30, 0, 0, .66)], fx: MontageFx.none, kick: 'Attention', title: 'Ouvre la bouche !', font: MontageFont.anton,
      accent: const Color(0xFFFF6A00), chip: '🔥 Fais le même', sound: 'Épique',
      texts: ['Quand je suis de mauvaise humeur le lundi 🔥', 'Ne me parle pas avant mon café ☕🐉', 'Le dragon est réveillé 🐉'],
      face: const TemplateFace(avatar: 'dragon', magic: 'Feu', gesture: 'mouth')),
  // Compte à rebours jusqu'à une date : anniversaire et événement à venir. Les widgets sont posés d'office et se modifient (date, texte, lieu, numéro).
  MontageTemplate(id: 'anniv_minuteur', cat: MontageCat.fetes, name: 'Anniversaire — compte à rebours', sample: _p4,
      tint: [_a(0, 0, 0, 0), _a(60, 0, 80, .62)], fx: MontageFx.confetti, kick: 'Bientôt', title: 'Mon anniversaire 🎂', longTitle: true,
      accent: const Color(0xFFFFD400), chip: '🎁 Réponds-moi en commentaire', sound: 'Joyeux anniversaire afro',
      texts: ['Plus que quelques jours avant mon anniversaire, vous êtes prêts ? 🎉', 'Le compte à rebours est lancé, rendez-vous à la fête 🥳'],
      presetWidgets: () => [
            PostWidget(kind: WidgetKind.countdown, config: {'title': 'Mon anniversaire', 'at': montageInDays(14, 18)}, x: .5, y: .3),
            PostWidget(kind: WidgetKind.place, config: {'name': 'Chez moi', 'maps_url': ''}, x: .5, y: .72),
          ]),
  MontageTemplate(id: 'evenement', cat: MontageCat.fetes, name: 'Événement à venir', sample: _p2,
      tint: [_a(0, 0, 0, .08), _a(20, 20, 60, .66)], fx: MontageFx.none, kick: 'Save the date', title: 'On vous attend !', font: MontageFont.anton,
      accent: const Color(0xFFFFD400), chip: '📍 Réservez votre place', sound: 'Afrobeat',
      texts: ['Notez la date, ça va être grand ! 🔥', 'Venez nombreux, l’entrée est ouverte à tous 🙌'],
      presetWidgets: () => [
            PostWidget(kind: WidgetKind.countdown, config: {'title': 'Début de l’événement', 'at': montageInDays(12, 19)}, x: .5, y: .26),
            PostWidget(kind: WidgetKind.place, config: {'name': 'Lieu de l’événement', 'maps_url': ''}, x: .5, y: .56),
          ]),
  MontageTemplate(id: 'diplome', cat: MontageCat.fetes, name: 'Diplômé(e)', sample: _p2,
      tint: [_a(0, 0, 0, 0), _a(20, 20, 70, .74)], tintStops: const [.35, 1], fx: MontageFx.confetti, frame: MontageFrame.gold, kick: 'Promotion $_nextYear', title: 'Diplômé(e) 🎓', font: MontageFont.anton,
      accent: const Color(0xFFFFD400), chip: '🎓 Mission accomplie',
      texts: ['Des nuits blanches, des sacrifices… et enfin le diplôme 🎓', 'Merci à ma famille, cette réussite est aussi la vôtre ❤️', 'Diplômé(e) ! La suite s’annonce belle 🚀']),
  MontageTemplate(id: 'nouveaujob', cat: MontageCat.fetes, name: 'Nouveau job', sample: _p4,
      tint: [_a(0, 0, 0, 0), _a(0, 40, 60, .72)], tintStops: const [.35, 1], fx: MontageFx.rays, kick: 'Nouveau départ', title: 'Nouveau job 💼', font: MontageFont.anton,
      accent: const Color(0xFF7FE7FF), chip: '💼 Premier jour',
      texts: ['Nouveau poste, nouvelle aventure. Merci Seigneur 🙏', 'Le travail paie : je commence lundi 💼', 'Une porte s’est ouverte, je fonce 🚀']),
  // ── Émotions (suite) ──
  MontageTemplate(id: 'triste', cat: MontageCat.emotions, name: 'Triste', sample: _p1, saturation: .45, brightness: -.06,
      tint: [_a(40, 60, 110, .4), _a(5, 10, 30, .78)], fx: MontageFx.rain, pos: MontagePos.center, kick: 'Humeur du jour', title: 'Triste 😢',
      accent: const Color(0xFF9EC5FF),
      texts: ['Certains jours sont plus lourds que d’autres 😢', 'Le cœur est fatigué, mais il tient bon 🌧️', 'Pas envie de parler aujourd’hui… 🤍']),
  MontageTemplate(id: 'manque', cat: MontageCat.emotions, name: 'Tu me manques', sample: _p6, saturation: .7,
      tint: [_a(255, 120, 160, .08), _a(60, 0, 40, .72)], fx: MontageFx.hearts, kick: 'Loin des yeux', title: 'Tu me manques 🥺', font: MontageFont.script,
      accent: const Color(0xFFFFB3C7),
      texts: ['Loin des yeux, jamais loin du cœur, {prenom} 🥺', 'La distance est longue, mais mon amour est plus fort ❤️', 'Je compte les jours avant de te revoir ⏳']),
  MontageTemplate(id: 'gratitude', cat: MontageCat.emotions, name: 'Reconnaissant(e)', sample: _p5,
      tint: [_a(255, 210, 120, .12), _a(90, 50, 0, .62)], fx: MontageFx.rays, kick: 'Merci', title: 'Reconnaissant(e) 🙏', longTitle: true,
      accent: const Color(0xFFFFE08A),
      texts: ['Merci pour la vie, la santé et ceux que j’aime 🙏', 'Je ne demande rien aujourd’hui, je dis juste merci ✨', 'Béni(e) au-delà de ce que je mérite 🤲🏾']),
  MontageTemplate(id: 'beni', cat: MontageCat.emotions, name: 'Béni(e)', sample: _p3,
      tint: [_a(255, 240, 200, .1), _a(70, 50, 10, .66)], fx: MontageFx.sparkle, frame: MontageFrame.gold, kick: 'Grâce à Dieu', title: 'Béni(e) ✨', font: MontageFont.script,
      accent: const Color(0xFFFFE7A3),
      texts: ['Tout ce que j’ai, je le dois à Dieu ✨', 'Béni(e) et reconnaissant(e), chaque jour 🙏', 'Ma foi est plus grande que mes peurs 🕊️']),
  MontageTemplate(id: 'motive', cat: MontageCat.emotions, name: 'Motivé(e)', sample: _p2, saturation: 1.15,
      tint: [_a(0, 0, 0, .1), _a(70, 20, 0, .6)], fx: MontageFx.fire, kick: 'Objectif', title: 'Motivé(e) 🚀', font: MontageFont.anton,
      accent: const Color(0xFFFF8A3B), chip: '🎯 Objectif en vue',
      texts: ['Je ne lâche rien, je vise plus haut 🚀', 'Chaque jour est une nouvelle chance d’avancer 💪', 'Ils doutent ? Parfait, je vais leur montrer 😤']),
  MontageTemplate(id: 'fier', cat: MontageCat.emotions, name: 'Fier(e) de moi', sample: _p4,
      tint: [_a(0, 0, 0, 0), _a(60, 0, 80, .66)], tintStops: const [.3, 1], fx: MontageFx.crown, kick: 'Je l’ai fait', title: 'Fier(e) de moi 🏆', longTitle: true, font: MontageFont.anton,
      accent: const Color(0xFFFFD400),
      texts: ['Je me regarde et je suis fier(e) du chemin parcouru 🏆', 'Personne n’y croyait. Moi si 💪', 'Petit à petit, j’ai construit mon rêve ✨']),
  MontageTemplate(id: 'choque', cat: MontageCat.emotions, name: 'Choqué(e)', sample: _p7, saturation: .9,
      tint: [_a(0, 0, 0, .25), _a(30, 0, 50, .72)], fx: MontageFx.storm, pos: MontagePos.center, kick: 'Breaking news', title: 'Choqué(e) 😱', font: MontageFont.anton,
      accent: const Color(0xFFFFE600),
      texts: ['Je viens d’apprendre la nouvelle… je suis sans voix 😱', 'Quelqu’un peut m’expliquer ce qui se passe ? 😳', 'Celle-là, je ne l’avais pas vue venir 🤯']),
  MontageTemplate(id: 'colere', cat: MontageCat.emotions, name: 'En colère', sample: _p5, saturation: .85,
      tint: [_a(120, 0, 0, .25), _a(40, 0, 0, .78)], fx: MontageFx.fire, kick: 'Attention', title: 'En colère 😡', font: MontageFont.anton,
      accent: const Color(0xFFFF5A4E),
      texts: ['Ne me cherchez pas aujourd’hui 😡', 'Ma patience a des limites, et on les a trouvées 😤', 'Je respire… je respire… 🔥']),
  MontageTemplate(id: 'stresse', cat: MontageCat.emotions, name: 'Stressé(e)', sample: _p1, saturation: .6,
      tint: [_a(50, 50, 70, .35), _a(15, 15, 30, .76)], fx: MontageFx.cloud, kick: 'Mode survie', title: 'Stressé(e) 😰',
      accent: const Color(0xFFB8C4D9), chip: '📚 J-3 avant l’examen',
      texts: ['Examens, travail, factures… respire 😰', 'Le stress passe, la réussite reste 💪', 'Priez pour moi, la semaine est chargée 🙏']),
  MontageTemplate(id: 'nostalgie', cat: MontageCat.emotions, name: 'Nostalgique', sample: _p3, saturation: .5,
      tint: [_a(160, 110, 60, .3), _a(50, 30, 10, .7)], fx: MontageFx.bokeh, kick: 'Souvenirs', title: 'Nostalgique 🕰️', font: MontageFont.script,
      accent: const Color(0xFFF2D3A0),
      texts: ['Ces moments-là ne reviendront pas, mais ils restent dans mon cœur 🕰️', 'Le bon vieux temps me manque 🥹', 'Si je pouvais revenir en arrière une seule journée… ✨']),
  MontageTemplate(id: 'crush', cat: MontageCat.emotions, name: 'J’ai un crush', sample: _p6,
      tint: [_a(255, 100, 160, .12), _a(110, 0, 70, .62)], fx: MontageFx.hearts, kick: 'Chut…', title: 'J’ai un crush 🙈', font: MontageFont.script,
      accent: const Color(0xFFFFB3C7), chip: '🙈 Il/elle se reconnaîtra',
      texts: ['Quelqu’un me fait sourire sans le savoir 🙈', 'Mon cœur bat plus vite quand tu passes 💓', 'Je ne dirai pas qui… mais il/elle se reconnaîtra 😏']),
  MontageTemplate(id: 'pardon', cat: MontageCat.emotions, name: 'Pardon', sample: _p5, saturation: .7,
      tint: [_a(200, 200, 255, .08), _a(30, 30, 60, .7)], fx: MontageFx.bokeh, pos: MontagePos.center, kick: 'Du fond du cœur', title: 'Pardon 🙏', font: MontageFont.script,
      accent: const Color(0xFFD9E2FF),
      texts: ['Je me suis trompé(e). Pardon du fond du cœur 🙏', 'Mon orgueil n’est rien à côté de notre amitié 🤍', 'Donne-moi une seconde chance, {prenom} 🕊️']),
  MontageTemplate(id: 'hate', cat: MontageCat.emotions, name: 'Trop hâte', sample: _p3,
      tint: [_a(255, 200, 0, .1), _a(90, 0, 90, .58)], fx: MontageFx.confetti, kick: 'Compte à rebours', title: 'Trop hâte 🤩', font: MontageFont.anton,
      accent: const Color(0xFFFFD400), chip: '⏳ Bientôt',
      texts: ['Plus que quelques jours et c’est le grand moment 🤩', 'Je ne tiens plus en place ! 🎉', 'Vous êtes prêts ? Moi, plus que jamais 🔥']),
  MontageTemplate(id: 'trahi', cat: MontageCat.situations, name: 'Trahi(e)', sample: _p7, saturation: .45, brightness: -.05,
      tint: [_a(30, 30, 60, .45), _a(5, 5, 20, .8)], fx: MontageFx.rain, kick: 'Leçon apprise', title: 'Trahi(e) 💔',
      accent: const Color(0xFF9EC5FF),
      texts: ['Ce ne sont pas mes ennemis qui m’ont blessé(e)… 💔', 'Leçon apprise : tout le monde n’est pas ton ami 🤐', 'Je pardonne, mais je n’oublie pas 🌧️']),
  // ── Insta ──
  MontageTemplate(id: 'ootd', cat: MontageCat.insta, name: 'Look du jour (OOTD)', sample: _p1,
      tint: [_a(0, 0, 0, 0), _a(0, 0, 0, .62)], tintStops: const [.45, 1], fx: MontageFx.sparkle, frame: MontageFrame.gold, kick: 'Outfit of the day', title: 'Look du jour ✨', font: MontageFont.anton,
      accent: const Color(0xFFFFD400), chip: '👗 #OOTD',
      texts: ['Le style, c’est dire qui tu es sans parler ✨', 'Tenue validée ? Dites-moi en commentaire 👇🏾', 'Wax, confiance et bonne humeur 💃🏾']),
  MontageTemplate(id: 'selfie', cat: MontageCat.insta, name: 'Selfie du jour', sample: _p3,
      tint: [_a(255, 200, 220, .06), _a(80, 0, 60, .5)], tintStops: const [.5, 1], fx: MontageFx.sparkle, kick: 'Selfie time', title: 'Selfie du jour 🤳🏾', font: MontageFont.script,
      accent: const Color(0xFFFFC6E0),
      texts: ['Pas de filtre, juste moi 🤳🏾', 'Sourire du jour offert gratuitement 😁', 'Il fallait bien immortaliser cette mine 😌']),
  MontageTemplate(id: 'tbt', cat: MontageCat.insta, name: 'Throwback (#TBT)', sample: _p4, saturation: .35,
      tint: [_a(170, 120, 60, .35), _a(50, 30, 10, .66)], fx: MontageFx.bokeh, kick: 'Throwback Thursday', title: '#TBT 📼', font: MontageFont.anton,
      accent: const Color(0xFFF2D3A0), chip: '📼 Souvenir',
      texts: ['Retour en arrière : qui se souvient de ce moment ? 📼', 'Ancienne photo, souvenirs intacts ❤️', 'On était jeunes et insouciants 😂']),
  MontageTemplate(id: 'weekend', cat: MontageCat.insta, name: 'Enfin le week-end', sample: kMontageSampleVideo, sampleIsVideo: true,
      tint: [_a(80, 0, 120, .25), _a(20, 0, 40, .7)], fx: MontageFx.confetti, kick: 'Vendredi soir', title: 'Enfin le week-end 🎉', longTitle: true, font: MontageFont.anton,
      accent: const Color(0xFFFF4FD8),
      texts: ['Le week-end est là, les soucis restent au bureau 🎉', 'Programme : dormir, manger, danser, recommencer 😎', 'Qui sort ce soir ? 🪩']),
  MontageTemplate(id: 'lundi', cat: MontageCat.insta, name: 'Lundi motivation', sample: _p2,
      tint: [_a(0, 0, 0, 0), _a(0, 30, 60, .7)], tintStops: const [.3, 1], fx: MontageFx.speed, kick: 'Nouvelle semaine', title: 'Lundi motivation ☕', longTitle: true, font: MontageFont.anton,
      accent: const Color(0xFF7FE7FF), chip: '☕ Café n°2',
      texts: ['Nouvelle semaine, nouvelles opportunités ☕', 'Le lundi ne me fait pas peur 💪', 'Objectifs de la semaine : tout donner 🎯']),
  MontageTemplate(id: 'vibe', cat: MontageCat.insta, name: 'Ma vibe du moment', sample: _p6,
      tint: [_a(255, 140, 0, .1), _a(100, 0, 60, .58)], fx: MontageFx.rays, kick: 'Current mood', title: 'Ma vibe 🎧', font: MontageFont.script,
      accent: const Color(0xFFFFB13B), chip: '🎧 En boucle',
      texts: ['Casque sur les oreilles, le monde peut attendre 🎧', 'Cette musique décrit exactement mon humeur 🎶', 'Bonne vibe uniquement ✨']),
  MontageTemplate(id: 'miam', cat: MontageCat.insta, name: 'Miam du jour', sample: _p4, saturation: 1.2,
      tint: [_a(255, 160, 60, .1), _a(80, 30, 0, .6)], tintStops: const [.4, 1], fx: MontageFx.bokeh, kick: 'Au menu', title: 'Miam 😋', font: MontageFont.anton,
      accent: const Color(0xFFFFC65C), chip: '🍽️ Fait maison',
      texts: ['Garba, attiéké, alloco… qui a faim ? 😋', 'La cuisine de maman reste imbattable 🍲', 'Régime ? Demain. Aujourd’hui, on mange 😂']),
  MontageTemplate(id: 'voyage', cat: MontageCat.insta, name: 'En voyage', sample: _p2,
      tint: [_a(255, 170, 80, .2), _a(40, 20, 80, .55)], fx: MontageFx.sunset, pos: MontagePos.top, kick: 'Carnet de voyage', title: 'En voyage ✈️', font: MontageFont.script,
      accent: const Color(0xFFFFD28A), chip: '📍 Nouvelle destination',
      texts: ['Nouvelle ville, nouvelles histoires ✈️', 'Voyager, c’est la seule dépense qui rend plus riche 🌍', 'Devinez où je suis ? 📍']),
  MontageTemplate(id: 'avis', cat: MontageCat.insta, name: 'Votre avis ?', sample: _p3,
      tint: [_a(0, 0, 0, 0), _a(0, 0, 0, .7)], tintStops: const [.4, 1], fx: MontageFx.sparkle, pos: MontagePos.center, kick: 'Question du jour', title: 'Votre avis ? 🤔', font: MontageFont.anton,
      accent: const Color(0xFFFFD400), chip: '💬 Réponds en commentaire',
      texts: ['Cette tenue : 🔥 ou ❌ ? Répondez en commentaire 👇🏾', 'Coiffure longue ou courte ? Votez 👇🏾', 'Je garde ou je change ? Dites-moi 🤔']),

  // ── Musique et ambiances musicales ──
  MontageTemplate(id: 'chanson', cat: MontageCat.music, name: 'Ma chanson du moment', sample: _p6,
      tint: [_a(90, 0, 140, .2), _a(25, 0, 50, .68)], fx: MontageFx.waves, kick: 'En écoute', title: 'Ma chanson du moment 🎧', longTitle: true, font: MontageFont.script,
      accent: const Color(0xFFFF9BE0), chip: '🎵 En boucle', sound: 'Afrobeat doux',
      texts: ['Cette chanson tourne en boucle depuis ce matin 🎧', 'Quand les paroles disent exactement ce que je ressens 🎶', 'Dis-moi la tienne en commentaire 👇🏾']),
  MontageTemplate(id: 'dedicace', cat: MontageCat.music, name: 'Dédicace musicale', sample: _p1,
      tint: [_a(255, 60, 120, .12), _a(100, 0, 50, .64)], fx: MontageFx.hearts, kick: 'Dédicace', title: 'Cette chanson est pour toi 💌', longTitle: true, font: MontageFont.script,
      accent: const Color(0xFFFFB3C7), chip: '💌 Pour toi', sound: 'Love song afro',
      texts: ['Cette chanson, c’est pour toi, {prenom}. Écoute-la jusqu’au bout 💌', 'Quand les mots ne suffisent pas, la musique parle 🎶', 'Dédicace spéciale à celui ou celle qui se reconnaîtra ❤️']),
  MontageTemplate(id: 'soiree', cat: MontageCat.music, name: 'Soirée Amapiano', sample: kMontageSampleVideo, sampleIsVideo: true,
      tint: [_a(20, 0, 80, .35), _a(5, 0, 25, .74)], fx: MontageFx.disco, kick: 'Ce week-end', title: 'Amapiano Night 🎹', font: MontageFont.anton,
      accent: const Color(0xFF7CF5FF), chip: '🎟️ On se retrouve où ?', sound: 'Amapiano club',
      texts: ['Les log drums sont de sortie, et toi ? 🎹', 'Amapiano toute la nuit, fatigue demain 💃🏾', 'Qui vient danser avec moi ce week-end ? 🔥']),
  MontageTemplate(id: 'chill', cat: MontageCat.music, name: 'Chill & lo-fi', sample: _p5, saturation: .8,
      tint: [_a(40, 30, 120, .3), _a(5, 5, 40, .72)], fx: MontageFx.moon, pos: MontagePos.center, kick: 'Mode chill', title: 'Chill 🌙', font: MontageFont.script,
      accent: const Color(0xFFBFD4FF), chip: '☕ Playlist du soir', sound: 'Nuit douce',
      texts: ['Casque, lumière tamisée, rien d’autre 🌙', 'Un son doux pour finir la journée ☕', 'Ma playlist pour se calmer le soir 🎧']),
  MontageTemplate(id: 'louange', cat: MontageCat.music, name: 'Louange & Gospel', sample: _p3, saturation: 1.1,
      tint: [_a(255, 210, 120, .3), _a(60, 30, 0, .55)], fx: MontageFx.rays, pos: MontagePos.center, kick: 'Louange', title: 'Dieu est bon 🙏🏾', font: MontageFont.script,
      accent: const Color(0xFFFFE7A3), chip: '🎶 Adoration', sound: 'Kora méditation',
      texts: ['Une chanson de louange pour bien commencer la journée 🙏🏾', 'Quand je chante, mon cœur se repose 🎶', 'À Dieu seul la gloire, aujourd’hui et toujours ✨']),
  MontageTemplate(id: 'freestyle', cat: MontageCat.music, name: 'Freestyle / Rap', sample: _p2,
      tint: [_a(0, 0, 0, .25), _a(40, 0, 0, .78)], fx: MontageFx.fire, kick: 'Freestyle', title: 'Freestyle 🎤', font: MontageFont.anton,
      accent: const Color(0xFFFF5A1F), chip: '🎤 16 mesures', sound: 'Afro trap',
      texts: ['16 mesures, zéro filtre. Dites-moi ce que vous en pensez 🎤', 'Le micro est ouvert, la rue écoute 🔥', 'Nouveau couplet, nouvelle énergie 🎤']),
  MontageTemplate(id: 'danse', cat: MontageCat.music, name: 'Défi danse', sample: kMontageSampleVideo, sampleIsVideo: true,
      tint: [_a(255, 80, 0, .15), _a(90, 0, 60, .62)], fx: MontageFx.confetti, kick: 'Défi danse', title: 'On danse ! 💃🏾', font: MontageFont.anton,
      accent: const Color(0xFFFFD400), chip: '🕺 Refais le pas', sound: 'Coupé-décalé',
      texts: ['Refais ce pas et identifie-moi 💃🏾', 'Impossible de rester assis(e) sur ce son 🕺🏾', 'Qui fait mieux ? Je vous attends 🔥']),
  MontageTemplate(id: 'slow', cat: MontageCat.music, name: 'Slow & RnB', sample: _p6, saturation: .9,
      tint: [_a(120, 20, 80, .28), _a(40, 0, 30, .7)], fx: MontageFx.sparkle, pos: MontagePos.bottom, kick: 'Slow du soir', title: 'Slow & RnB 🍷', font: MontageFont.script,
      accent: const Color(0xFFFFB3C7), chip: '🍷 Ambiance douce', sound: 'Love song afro',
      texts: ['Un slow, deux cœurs, la nuit pour nous 🍷', 'Le genre de chanson qui rappelle quelqu’un 🌹', 'RnB doux pour les âmes sensibles 🎶']),
  MontageTemplate(id: 'concert', cat: MontageCat.music, name: 'Concert / Live', sample: _p2,
      tint: [_a(0, 0, 60, .2), _a(15, 0, 40, .75)], fx: MontageFx.sparkle, kick: 'En direct', title: 'Concert live 🎤', font: MontageFont.anton,
      accent: const Color(0xFFFFD400), chip: '🎟️ Ce soir', sound: 'Afrobeat club',
      texts: ['Ambiance de feu au concert hier soir 🔥🎤', 'La scène, la foule, le frisson : je n’oublierai jamais 🎶', 'Qui y était avec moi ? 🙌🏾']),
  MontageTemplate(id: 'oldschool', cat: MontageCat.music, name: 'Le son d’avant', sample: _p4, saturation: .3,
      tint: [_a(170, 120, 60, .35), _a(50, 30, 10, .68)], fx: MontageFx.bokeh, kick: 'Old school', title: 'Le son d’avant 📼', font: MontageFont.anton,
      accent: const Color(0xFFF2D3A0), chip: '📼 Classique', sound: 'Highlife joyeux',
      texts: ['Avant, on savait faire de la vraie musique 📼', 'Ce son me ramène directement en enfance ❤️', 'Les anciens, vous connaissez cette chanson ? 🎶']),
  MontageTemplate(id: 'studio', cat: MontageCat.music, name: 'Au studio', sample: _p7, saturation: .7,
      tint: [_a(0, 0, 0, .3), _a(10, 0, 40, .78)], fx: MontageFx.rays, pos: MontagePos.top, kick: 'En studio', title: 'Nouveau son en préparation 🎛️', longTitle: true, font: MontageFont.anton,
      accent: const Color(0xFF7CF5FF), chip: '🎤 Bientôt disponible', sound: 'Afro trap',
      texts: ['Session studio : quelque chose de grand arrive 🎛️', 'Je ne dis rien, je vous laisse écouter bientôt 🤫🎤', 'Merci de votre soutien, le nouveau son arrive ! 🙏🏾']),
  MontageTemplate(id: 'sortie', cat: MontageCat.music, name: 'Nouveau son disponible', sample: _p1,
      tint: [_a(255, 160, 0, .12), _a(70, 0, 80, .66)], fx: MontageFx.crown, frame: MontageFrame.gold, kick: 'Nouveau single', title: 'Mon nouveau son est sorti 🔥', longTitle: true, font: MontageFont.anton,
      accent: const Color(0xFFFFD400), chip: '▶️ Disponible maintenant', sound: 'Afrobeat club',
      texts: ['Mon nouveau son est enfin disponible, écoutez et partagez 🔥', 'Merci à tous ceux qui m’ont soutenu(e) 🙏🏾 Le single est là !', 'Écoute-le, utilise-le dans ton post et identifie-moi 🎶']),
  MontageTemplate(id: 'focus', cat: MontageCat.music, name: 'Playlist focus', sample: _p5,
      tint: [_a(0, 80, 80, .2), _a(0, 25, 35, .72)], fx: MontageFx.waves, pos: MontagePos.center, kick: 'Mode focus', title: 'Playlist focus 🧠', font: MontageFont.bold,
      accent: const Color(0xFFA7F3D0), chip: '🎧 Pour travailler', sound: 'Kalimba zen',
      texts: ['La playlist qui m’aide à travailler sans me disperser 🧠', 'Casque sur les oreilles, objectifs en tête 🎧', 'Concentration maximale, notifications coupées 📵']),

  // ── Fêtes du calendrier (invitations J-3 à J : voir studio_fetes.dart) ──
  MontageTemplate(id: 'paques', cat: MontageCat.fetes, name: 'Pâques', sample: _p3,
      tint: [_a(255, 190, 90, .15), _a(90, 40, 120, .58)], fx: MontageFx.sparkle, kick: 'Joyeuses Pâques', title: 'Joyeuses Pâques 🐣', font: MontageFont.script,
      accent: const Color(0xFFFFE7A3), sound: 'Clochettes de fête',
      texts: ['Joyeuses Pâques à toute la famille 🐣', 'Que cette fête apporte paix et joie dans vos foyers ✨', 'Bonne fête de Pâques à tous ! 🌷']),
  MontageTemplate(id: 'meres', cat: MontageCat.fetes, name: 'Fête des mères', sample: _p6,
      tint: [_a(255, 80, 140, .1), _a(100, 0, 60, .62)], fx: MontageFx.hearts, kick: 'Fête des mères', title: 'Merci maman 💐', font: MontageFont.script,
      accent: const Color(0xFFFFB3C7), chip: '🎁 Offre un cadeau', sound: 'Love song afro',
      texts: ['Bonne fête maman, tu es mon plus beau cadeau 💐', 'Merci pour tout ce que tu fais en silence ❤️', 'Bonne fête à toutes les mamans du monde 💐']),
  MontageTemplate(id: 'peres', cat: MontageCat.fetes, name: 'Fête des pères', sample: _p2,
      tint: [_a(10, 40, 90, .2), _a(5, 15, 50, .7)], fx: MontageFx.rays, frame: MontageFrame.gold, kick: 'Fête des pères', title: 'Merci papa 👔', font: MontageFont.anton,
      accent: const Color(0xFFFFD400), sound: 'Highlife joyeux',
      texts: ['Bonne fête papa, mon premier héros 👔', 'Merci de m’avoir appris à rester debout 💪🏾', 'Bonne fête à tous les papas ! 🙏🏾']),
  MontageTemplate(id: 'femmes', cat: MontageCat.fetes, name: 'Journée de la femme (8 mars)', sample: _p1,
      tint: [_a(150, 30, 160, .2), _a(70, 0, 90, .66)], fx: MontageFx.crown, kick: '8 mars', title: 'Bonne journée aux femmes 💐', longTitle: true, font: MontageFont.script,
      accent: const Color(0xFFFFB3C7), sound: 'Afropop',
      texts: ['Bonne journée à toutes les femmes fortes et courageuses 💐', 'Reines, mères, sœurs, amies : vous êtes la force du monde 👑', 'Aujourd’hui et chaque jour, respect aux femmes 💜']),
  MontageTemplate(id: 'afrique', cat: MontageCat.fetes, name: 'Journée de l’Afrique (25 mai)', sample: _p2, saturation: 1.15,
      tint: [_a(255, 160, 0, .2), _a(90, 25, 0, .62)], fx: MontageFx.sunset, kick: '25 mai', title: 'Fier(e) d’être africain(e) 🌍', longTitle: true, font: MontageFont.anton,
      accent: const Color(0xFFFFD400), chip: '🌍 Une seule Afrique', sound: 'Djembé lointain',
      texts: ['Bonne Journée de l’Afrique à tout le continent 🌍', 'Une terre, mille couleurs, un seul cœur ❤️💛💚', 'Fier(e) de mes racines, aujourd’hui et toujours 🌍']),
  MontageTemplate(id: 'tabaski', cat: MontageCat.fetes, name: 'Tabaski (Aïd el-Kébir)', sample: _p5,
      tint: [_a(10, 40, 40, .4), _a(5, 20, 25, .76)], fx: MontageFx.moon, kick: 'Aïd el-Kébir', title: 'Bonne fête de la Tabaski 🐑', longTitle: true, font: MontageFont.script,
      accent: const Color(0xFFFFE7A3), sound: 'Oud doux',
      texts: ['Bonne fête de la Tabaski à toute la famille 🐑', 'Que Dieu accepte nos sacrifices et exauce nos prières 🤲🏾', 'Aïd Moubarak, paix et bénédictions à tous 🌙']),
  MontageTemplate(id: 'travail', cat: MontageCat.fetes, name: 'Fête du travail (1er mai)', sample: _p7, saturation: .8,
      tint: [_a(0, 40, 90, .25), _a(5, 15, 50, .7)], fx: MontageFx.sparkle, kick: '1er mai', title: 'Bonne fête du travail 🛠️', longTitle: true, font: MontageFont.anton,
      accent: const Color(0xFFFFD400), sound: 'Afro workout',
      texts: ['Bonne fête à tous ceux qui travaillent dur chaque jour 🛠️', 'Courage à tous les travailleurs, vos efforts comptent 💪🏾', 'Le travail honore, bonne fête du travail ! 🙏🏾']),
  // ── Fin d’année, ma vie, ambiances, pensées, weekend, événements, drôles (09/11/2026) ──
  MontageTemplate(id: 'fa_film', cat: MontageCat.finannee, name: 'Le film de mon année', sample: _p5, saturation: 0.2, pos: MontagePos.center,
      tint: [_a(0, 0, 0, 0.35), _a(0, 0, 0, 0.86)], fx: MontageFx.sparkle, kick: 'Générique', title: 'MON ANNÉE $_endingYear', font: MontageFont.anton,
      accent: const Color(0xFFD400), chip: '🎬 Fin', sound: 'Générique de fin',
      texts: ['Un film de moi, avec ma famille, mes amis, mes galères et mes victoires 🎬', 'Musique : mes playlists · Merci d’avoir regardé · FIN']),
  MontageTemplate(id: 'gen_journee', cat: MontageCat.vie, name: 'Ma journée en film', sample: _p3, saturation: 0.2, pos: MontagePos.center,
      tint: [_a(0, 0, 0, 0.35), _a(0, 0, 0, 0.86)], fx: MontageFx.sparkle, kick: 'Générique de la journée', font: MontageFont.anton,
      accent: const Color(0xFFFFD400), chip: '🎬 Fin', sound: 'Générique de fin'),
  MontageTemplate(id: 'gen_weekend', cat: MontageCat.vie, name: 'Mon week-end en film', sample: _p6, saturation: 0.2, pos: MontagePos.center,
      tint: [_a(0, 0, 0, 0.35), _a(0, 0, 0, 0.86)], fx: MontageFx.sparkle, kick: 'Générique du week-end', font: MontageFont.anton,
      accent: const Color(0xFFFFD400), chip: '🎬 Fin', sound: 'Générique de fin'),
  MontageTemplate(id: 'gen_histoire', cat: MontageCat.vie, name: 'Mon histoire en film', sample: _p2, saturation: 0.2, pos: MontagePos.center,
      tint: [_a(0, 0, 0, 0.35), _a(0, 0, 0, 0.86)], fx: MontageFx.sparkle, kick: 'Générique de mon histoire', font: MontageFont.anton,
      accent: const Color(0xFFFFD400), chip: '🎬 Fin', sound: 'Générique de fin'),
  MontageTemplate(id: 'gen_anniv', cat: MontageCat.vie, name: 'Mon anniversaire en film', sample: _p7, saturation: 0.2, pos: MontagePos.center,
      tint: [_a(0, 0, 0, 0.35), _a(0, 0, 0, 0.86)], fx: MontageFx.sparkle, kick: 'Générique de l’anniversaire', font: MontageFont.anton,
      accent: const Color(0xFFFFD400), chip: '🎬 Fin', sound: 'Générique de fin'),
  MontageTemplate(id: 'gen_voyage', cat: MontageCat.vie, name: 'Mon voyage en film', sample: _p4, saturation: 0.2, pos: MontagePos.center,
      tint: [_a(0, 0, 0, 0.35), _a(0, 0, 0, 0.86)], fx: MontageFx.sparkle, kick: 'Générique du voyage', font: MontageFont.anton,
      accent: const Color(0xFFFFD400), chip: '🎬 Fin', sound: 'Générique de fin'),
  MontageTemplate(id: 'gen_soiree', cat: MontageCat.vie, name: 'Ma soirée en film', sample: _p1, saturation: 0.2, pos: MontagePos.center,
      tint: [_a(0, 0, 0, 0.35), _a(0, 0, 0, 0.86)], fx: MontageFx.sparkle, kick: 'Générique de la soirée', font: MontageFont.anton,
      accent: const Color(0xFFFFD400), chip: '🎬 Fin', sound: 'Générique de fin'),
  MontageTemplate(id: 'gen_mariage', cat: MontageCat.vie, name: 'Notre mariage en film', sample: _p5, saturation: 0.2, pos: MontagePos.center,
      tint: [_a(0, 0, 0, 0.35), _a(0, 0, 0, 0.86)], fx: MontageFx.sparkle, kick: 'Générique du mariage', font: MontageFont.anton,
      accent: const Color(0xFFFFD400), chip: '🎬 Fin', sound: 'Générique de fin'),
  MontageTemplate(id: 'gen_business', cat: MontageCat.vie, name: 'Mon business en film', sample: _p6, saturation: 0.2, pos: MontagePos.center,
      tint: [_a(0, 0, 0, 0.35), _a(0, 0, 0, 0.86)], fx: MontageFx.sparkle, kick: 'Générique du business', font: MontageFont.anton,
      accent: const Color(0xFFFFD400), chip: '🎬 Fin', sound: 'Générique de fin'),
  MontageTemplate(id: 'gen_famille', cat: MontageCat.vie, name: 'Ma famille en film', sample: _p3, saturation: 0.2, pos: MontagePos.center,
      tint: [_a(0, 0, 0, 0.35), _a(0, 0, 0, 0.86)], fx: MontageFx.sparkle, kick: 'Générique de la famille', font: MontageFont.anton,
      accent: const Color(0xFFFFD400), chip: '🎬 Fin', sound: 'Générique de fin'),
  MontageTemplate(id: 'fa_triomphe', cat: MontageCat.finannee, name: 'De la galère au triomphe', sample: _p2, frame: MontageFrame.gold, saturation: 1.05,
      tint: [_a(255, 200, 0, 0.1), _a(60, 40, 0, 0.72)], fx: MontageFx.crown, kick: 'Janvier → Décembre', title: 'Du chaos au triomphe', font: MontageFont.anton,
      accent: const Color(0xFFD400), chip: '🏆 Je n’ai pas lâché', sound: 'Épique',
      texts: ['Janvier : les galères. Juin : le déclic. Décembre : le triomphe 🏆', 'Rien ne marchait, j’ai tenu, regardez où je suis arrivé(e) 🔥']),
  MontageTemplate(id: 'fa_merci', cat: MontageCat.finannee, name: 'Belle histoire : Merci $_endingYear', sample: _p6,
      tint: [_a(255, 60, 120, 0.12), _a(120, 0, 40, 0.62)], fx: MontageFx.sparkle, kick: 'Une belle année', title: 'Merci $_endingYear', font: MontageFont.script,
      accent: const Color(0xFFFFFFB3C7), chip: '❤️ Santé · famille · réussite', sound: 'Souvenirs',
      texts: ['Une belle année, une belle histoire. Merci à tous ceux qui en ont fait partie ❤️', 'Merci $_endingYear pour tout ce que tu m’as appris 🙏']),
  MontageTemplate(id: 'fa_page', cat: MontageCat.finannee, name: 'Je tourne la page', sample: _p5, pos: MontagePos.center, saturation: 0.45, dualSample: _p4,
      tint: [_a(20, 30, 60, 0.3), _a(0, 0, 20, 0.8)], fx: MontageFx.none, kick: '$_endingYear → $_nextYear', title: 'Je tourne la page', font: MontageFont.anton,
      accent: const Color(0xFFFFFF), chip: '🌅 Je choisis mieux', sound: 'Piano',
      texts: ['$_endingYear a été dure. J’ai perdu, j’ai pleuré, j’ai appris. $_nextYear sera différent.', 'Ce qui m’a fait mal ne me définit pas. Je construis la suite 🌅']),
  MontageTemplate(id: 'fa_change', cat: MontageCat.finannee, name: '$_endingYear s’en va, $_nextYear arrive', sample: _p3, saturation: 0.6,
      tint: [_a(0, 0, 40, 0.35), _a(0, 0, 20, 0.8)], fx: MontageFx.fireworks, kick: 'Minuit approche', title: '$_nextYear arrive', font: MontageFont.anton,
      accent: const Color(0xFFD400), chip: '🎆 Mon vœu pour $_nextYear', sound: 'Fête',
      texts: ['$_endingYear s’en va, merci pour les leçons. $_nextYear, je t’attends avec le sourire 🎆', 'Mon vœu pour $_nextYear : la paix, la santé et la réussite 🙏'],
      presetWidgets: () => [PostWidget(kind: WidgetKind.countdown, config: {'title': 'Minuit', 'at': _newYearEve()}, x: .5, y: 0.26)]),
  MontageTemplate(id: 'fa_bilan', cat: MontageCat.finannee, name: 'Mon bilan $_endingYear', sample: _p7, pos: MontagePos.top,
      tint: [_a(0, 0, 0, 0.05), _a(0, 0, 0, 0.6)], fx: MontageFx.confetti, kick: 'Bilan', title: 'Mon bilan $_endingYear', font: MontageFont.bold,
      accent: const Color(0xFFD400), chip: '📊 Ce que j’ai gagné · appris', sound: 'Highlife',
      texts: ['Ce que j’ai gagné, ce que j’ai perdu, ce que j’ai appris cette année 📊', 'Mon plus beau moment de $_endingYear : …']),
  MontageTemplate(id: 'fa_lecons', cat: MontageCat.finannee, name: 'Les leçons de $_endingYear', sample: _p6, pos: MontagePos.center, saturation: 0.9,
      tint: [_a(0, 60, 80, 0.15), _a(0, 20, 40, 0.7)], fx: MontageFx.bokeh, kick: 'Leçons', title: 'Ce que $_endingYear m’a appris', font: MontageFont.script,
      accent: const Color(0xFFFFFF), chip: '📚 Une leçon par mois', sound: 'Kalimba',
      texts: ['Les gens passent, les leçons restent 📚', 'Ne pas tout dire, ne pas tout donner, choisir mes combats.']),
  MontageTemplate(id: 'fa_resolutions', cat: MontageCat.finannee, name: 'Mes résolutions $_nextYear', sample: _p1, saturation: 1.05,
      tint: [_a(255, 200, 0, 0.1), _a(60, 40, 0, 0.72)], fx: MontageFx.rays, kick: 'Résolutions', title: 'Mes résolutions $_nextYear', font: MontageFont.anton,
      accent: const Color(0xFFD400), chip: '✅ 3 objectifs', sound: 'Motivation',
      texts: ['$_nextYear : plus de sport, plus de sourire, moins de stress 💪', 'Mes 3 objectifs pour $_nextYear : 1) … 2) … 3) …'],
      presetWidgets: () => [PostWidget(kind: WidgetKind.countdown, config: {'title': '{N} dans', 'at': _newYearEve()}, x: .5, y: 0.26)]),
  MontageTemplate(id: 'duo_reaction', cat: MontageCat.vie, name: 'Duo réaction', sample: _p4,
      tint: [_a(0, 0, 0, 0.05), _a(0, 0, 0, 0.55)], fx: MontageFx.none, kick: 'Réaction', title: 'Ma réaction', font: MontageFont.anton,
      accent: const Color(0xFFD400), chip: '🎬 2 vidéos', sound: 'Chill',
      texts: ['Ma tête quand j’ai vu ça 😂', 'La vidéo en haut, ma réaction en bas']),
  MontageTemplate(id: 'duo_cote', cat: MontageCat.vie, name: 'Côte à côte', sample: _p6,
      tint: [_a(0, 0, 0, 0.05), _a(0, 0, 0, 0.55)], fx: MontageFx.none, kick: 'Duo', title: 'Deux vidéos, un seul écran', font: MontageFont.anton,
      accent: const Color(0xFFD400), chip: '🎞️ 2 vidéos', sound: 'Chill',
      texts: ['Toi et moi, chacun dans son coin, ensemble 💞']),
  MontageTemplate(id: 'duo_avant_apres_video', cat: MontageCat.vie, name: 'Avant / Après en vidéo', sample: _p2,
      tint: [_a(0, 0, 0, 0.05), _a(0, 0, 0, 0.55)], fx: MontageFx.none, kick: 'Transformation', title: 'Avant / Après', font: MontageFont.anton,
      accent: const Color(0xFFD400), chip: '🔄 2 vidéos', sound: 'Chill',
      texts: ['Avant à gauche, après à droite : regarde la différence 💪']),
  MontageTemplate(id: 'multi_toi_lui', cat: MontageCat.vie, name: 'Toi ou lui ?', sample: _p3,
      tint: [_a(0, 0, 0, 0.05), _a(0, 0, 0, 0.55)], fx: MontageFx.none, kick: 'Vote', title: 'Qui gagne ?', font: MontageFont.anton,
      accent: const Color(0xFFD400), chip: '🗳️ 2 photos', sound: 'Chill',
      texts: ['Deux photos face à face : vous votez, le score s’affiche en direct 🗳️']),
  MontageTemplate(id: 'multi_boutique', cat: MontageCat.evenements, name: 'Mini-boutique', sample: _p7,
      tint: [_a(0, 0, 0, 0.05), _a(0, 0, 0, 0.55)], fx: MontageFx.none, kick: 'Boutique', title: 'Mini-boutique', font: MontageFont.anton,
      accent: const Color(0xFFD400), chip: '🛍️ 4 photos', sound: 'Chill',
      texts: ['Un produit, son prix, sa promo, l’avis des clients : ajoutez votre bouton WhatsApp 🛍️']),
  MontageTemplate(id: 'multi_recette', cat: MontageCat.vie, name: 'Recette express', sample: _p6,
      tint: [_a(0, 0, 0, 0.05), _a(0, 0, 0, 0.55)], fx: MontageFx.none, kick: 'Recette', title: 'Recette express', font: MontageFont.anton,
      accent: const Color(0xFFD400), chip: '🍲 4 photos', sound: 'Chill',
      texts: ['Le plat, trois ingrédients, la durée : une recette en un coup d’œil 🍲']),
  MontageTemplate(id: 'multi_avant_apres', cat: MontageCat.vie, name: 'Avant / Après', sample: _p2,
      tint: [_a(0, 0, 0, 0.05), _a(0, 0, 0, 0.6)], fx: MontageFx.none, kick: 'Transformation', title: 'Ma transformation', font: MontageFont.bold,
      accent: const Color(0xFFD400), chip: '🔄 2 photos', sound: 'Chill',
      texts: ['Avant, après : la preuve que tout est possible 💪']),
  MontageTemplate(id: 'multi_duo', cat: MontageCat.vie, name: 'Nous deux', sample: _p6,
      tint: [_a(0, 0, 0, 0.05), _a(0, 0, 0, 0.6)], fx: MontageFx.none, kick: 'Duo', title: 'Nous deux', font: MontageFont.bold,
      accent: const Color(0xFFD400), chip: '💞 2 photos', sound: 'Chill',
      texts: ['Toi, moi et tous nos souvenirs 💞']),
  MontageTemplate(id: 'multi_cinq_moments', cat: MontageCat.vie, name: 'Mon année en 5 photos', sample: _p5,
      tint: [_a(0, 0, 0, 0.05), _a(0, 0, 0, 0.6)], fx: MontageFx.none, kick: 'Souvenirs', title: 'Mes 5 moments', font: MontageFont.bold,
      accent: const Color(0xFFD400), chip: '📸 5 photos', sound: 'Chill',
      texts: ['Mes 5 plus beaux moments de l’année 📸']),
  MontageTemplate(id: 'multi_quatre_saisons', cat: MontageCat.vie, name: 'Mon année en 4 photos', sample: _p7,
      tint: [_a(0, 0, 0, 0.05), _a(0, 0, 0, 0.6)], fx: MontageFx.none, kick: 'Bilan', title: 'Mon année en 4 photos', font: MontageFont.bold,
      accent: const Color(0xFFD400), chip: '🗓️ 4 photos', sound: 'Chill',
      texts: ['Mars, juin, septembre, décembre : mon année en 4 images 🗓️']),
  MontageTemplate(id: 'vie_moi', cat: MontageCat.vie, name: 'Voici qui je suis', sample: _p3, pos: MontagePos.center,
      tint: [_a(0, 0, 0, 0.05), _a(0, 0, 0, 0.6)], fx: MontageFx.none, kick: 'Moi', title: 'Voici qui je suis', font: MontageFont.bold,
      accent: const Color(0xFFD400), chip: '✨ Authentique', sound: 'Chill',
      texts: ['Je ne suis pas parfait(e), mais je suis authentique ✨', 'Mes défauts, mes rêves, mes combats : tout ça, c’est moi.']),
  MontageTemplate(id: 'vie_devenu', cat: MontageCat.vie, name: 'Ce que je suis devenu(e)', sample: _p2, pos: MontagePos.top, saturation: 1.05,
      tint: [_a(255, 200, 0, 0.1), _a(60, 40, 0, 0.72)], fx: MontageFx.crown, kick: 'Évolution', title: 'Regardez qui je suis devenu(e)', font: MontageFont.anton,
      accent: const Color(0xFFD400), chip: '👑 Pas à pas', sound: 'Épique',
      texts: ['Avant : doute et peur. Aujourd’hui : fier(e) et debout 👑', 'Personne n’a vu les nuits où j’ai failli abandonner.']),
  MontageTemplate(id: 'vie_chemin', cat: MontageCat.vie, name: 'Mon chemin', sample: _p4, pos: MontagePos.center, saturation: 0.45,
      tint: [_a(20, 30, 60, 0.3), _a(0, 0, 20, 0.8)], fx: MontageFx.leaves, kick: 'Mon histoire', title: 'Mon chemin n’a pas été facile', font: MontageFont.script,
      accent: const Color(0xFFFFFF), chip: '🛤️ Un pas après l’autre', sound: 'Piano',
      texts: ['Un jour, je raconterai tout. En attendant, j’avance.', 'Chaque cicatrice est une histoire que j’ai survécu.']),
  MontageTemplate(id: 'vie_bebe', cat: MontageCat.vie, name: 'Notre bébé arrive', sample: _p6,
      tint: [_a(255, 60, 120, 0.12), _a(120, 0, 40, 0.62)], fx: MontageFx.baby, kick: 'Bientôt', title: 'Notre bébé arrive', font: MontageFont.script,
      accent: const Color(0xFFFFFFB3C7), chip: '👶 Compte à rebours', sound: 'Berceuse',
      texts: ['Plus que quelques semaines avant de te rencontrer 👶', 'Déjà tellement aimé(e), même avant ta naissance ❤️'],
      presetWidgets: () => [PostWidget(kind: WidgetKind.countdown, config: {'title': 'Arrivée du bébé', 'at': montageInDays(90, 9)}, x: .5, y: 0.26)]),
  MontageTemplate(id: 'vie_mariage', cat: MontageCat.vie, name: 'Le grand jour', sample: _p6, frame: MontageFrame.gold,
      tint: [_a(255, 60, 120, 0.12), _a(120, 0, 40, 0.62)], fx: MontageFx.ring, kick: 'Save the date', title: 'Nous allons nous marier', font: MontageFont.script,
      accent: const Color(0xFFFFFFB3C7), chip: '💍 Soyez des nôtres', sound: 'Love',
      texts: ['Notre histoire continue, venez la fêter avec nous 💍', 'Le grand jour approche, notez la date !'],
      presetWidgets: () => [PostWidget(kind: WidgetKind.countdown, config: {'title': 'Le grand jour', 'at': montageInDays(60, 11)}, x: .5, y: 0.26), PostWidget(kind: WidgetKind.place, config: {'name': 'Lieu de la cérémonie', 'maps_url': ''}, x: .5, y: 0.6)]),
  MontageTemplate(id: 'vie_maison', cat: MontageCat.vie, name: 'Nouvelle maison', sample: _p1, saturation: 1.15,
      tint: [_a(255, 200, 0, 0.08), _a(120, 40, 0, 0.55)], fx: MontageFx.sparkle, kick: 'Nouveau chez-moi', title: 'Bienvenue chez moi', font: MontageFont.bold,
      accent: const Color(0xFFD400), chip: '🏠 Clés en main', sound: 'Highlife',
      texts: ['Une nouvelle maison, de nouveaux souvenirs 🏠', 'Merci à ceux qui ont cru en moi quand je n’avais rien.']),
  MontageTemplate(id: 'vie_premier', cat: MontageCat.vie, name: 'Premier jour de travail', sample: _p4, pos: MontagePos.top,
      tint: [_a(0, 0, 0, 0.05), _a(0, 0, 0, 0.6)], fx: MontageFx.rays, kick: 'Nouveau départ', title: 'Premier jour !', font: MontageFont.anton,
      accent: const Color(0xFFD400), chip: '💼 Stress et fierté', sound: 'Motivation',
      texts: ['Premier jour de travail : stress, fierté, café ☕', 'On a commencé tout en bas, aujourd’hui on entre par la grande porte 💼']),
  MontageTemplate(id: 'vie_voyage', cat: MontageCat.vie, name: 'Départ en voyage', sample: _p7, saturation: 0.9,
      tint: [_a(0, 60, 80, 0.15), _a(0, 20, 40, 0.7)], fx: MontageFx.sunset, kick: 'Prochain vol', title: 'On décolle !', font: MontageFont.anton,
      accent: const Color(0xFFD400), chip: '✈️ Valises prêtes', sound: 'Plage',
      texts: ['Valises prêtes, passeport en main, cœur léger ✈️', 'Le voyage commence avant même de partir.'],
      presetWidgets: () => [PostWidget(kind: WidgetKind.countdown, config: {'title': 'Départ', 'at': montageInDays(7, 9)}, x: .5, y: 0.26)]),
  MontageTemplate(id: 'vie_hommage', cat: MontageCat.vie, name: 'Hommage à un proche', sample: _p4, pos: MontagePos.center, saturation: 0.2,
      tint: [_a(0, 0, 0, 0.35), _a(0, 0, 0, 0.86)], fx: MontageFx.none, kick: 'En mémoire', title: 'Tu resteras dans mon cœur', font: MontageFont.script,
      accent: const Color(0xFFFFFF), chip: '🕊️ Repose en paix', sound: 'Piano',
      texts: ['Les gens qu’on aime ne partent jamais vraiment 🕊️', 'Merci pour tout ce que tu m’as appris. Tu me manques.']),
  MontageTemplate(id: 'vie_retrouv', cat: MontageCat.vie, name: 'Retrouvailles', sample: _p2, saturation: 1.15,
      tint: [_a(255, 200, 0, 0.08), _a(120, 40, 0, 0.55)], fx: MontageFx.hearts, kick: 'Enfin !', title: 'Ça fait trop longtemps', font: MontageFont.bold,
      accent: const Color(0xFFD400), chip: '🤗 Les vrais sont là', sound: 'Highlife',
      texts: ['Retrouvailles après des années : rien n’a changé 🤗', 'Les vrais amis, c’est comme si on s’était quittés hier.']),
  MontageTemplate(id: 'vie_combat', cat: MontageCat.vie, name: 'Mon combat', sample: _p5, saturation: 0.8,
      tint: [_a(120, 0, 0, 0.2), _a(40, 0, 0, 0.78)], fx: MontageFx.none, kick: 'Mon combat', title: 'Je ne lâcherai pas', font: MontageFont.anton,
      accent: const Color(0xFFFFFF), chip: '💪 Je me bats', sound: 'Épique',
      texts: ['Ce combat, je le mène en silence mais je le gagnerai 💪', 'Merci à ceux qui prient pour moi, j’avance.']),
  MontageTemplate(id: 'vie_objectifs', cat: MontageCat.vie, name: 'Mes objectifs', sample: _p3, pos: MontagePos.top, saturation: 1.05,
      tint: [_a(255, 200, 0, 0.1), _a(60, 40, 0, 0.72)], fx: MontageFx.rays, kick: 'Objectifs', title: 'Jour 1', font: MontageFont.anton,
      accent: const Color(0xFFD400), chip: '🎯 Un jour à la fois', sound: 'Motivation',
      texts: ['Jour 1 : je commence. Jour 100 : vous verrez 🎯', 'Pas de miracle, juste de la discipline.']),
  MontageTemplate(id: 'vie_famille', cat: MontageCat.vie, name: 'Ma famille', sample: _p6, frame: MontageFrame.wax, saturation: 1.15,
      tint: [_a(255, 200, 0, 0.08), _a(120, 40, 0, 0.55)], fx: MontageFx.hearts, kick: 'Famille', title: 'Ma force, c’est eux', font: MontageFont.script,
      accent: const Color(0xFFFFFFB3C7), chip: '👨‍👩‍👧 Tout pour eux', sound: 'Love',
      texts: ['Ma famille, mon refuge, ma raison de me lever chaque matin 👨‍👩‍👧', 'Merci d’être mes premiers supporters.']),
  MontageTemplate(id: 'vie_age', cat: MontageCat.vie, name: 'Mon âge, ma sagesse', sample: _p1, pos: MontagePos.center, saturation: 0.9,
      tint: [_a(0, 60, 80, 0.15), _a(0, 20, 40, 0.7)], fx: MontageFx.bokeh, kick: 'Un an de plus', title: 'Plus sage, plus fort(e)', font: MontageFont.bold,
      accent: const Color(0xFFD400), chip: '🎂 Ce que j’ai appris', sound: 'Kalimba',
      texts: ['Un an de plus : moins de bruit, plus de paix 🎂', 'Le temps m’a appris qui compte vraiment.']),
  MontageTemplate(id: 'vie_signe', cat: MontageCat.vie, name: 'Mon caractère', sample: _p2,
      tint: [_a(0, 0, 0, 0), _a(60, 0, 80, 0.62)], fx: MontageFx.sparkle, kick: 'Personnalité', title: 'Voilà mon caractère', font: MontageFont.bold,
      accent: const Color(0xFFD400), chip: '🔮 Tu me reconnais ?', sound: 'Amapiano',
      texts: ['Calme au début, explosif si on me cherche 🔮', 'Je suis cool, sauf quand on me manque de respect.']),
  MontageTemplate(id: 'vie_introvertie', cat: MontageCat.vie, name: 'Introverti(e) et fier(e)', sample: _p4, pos: MontagePos.center, saturation: 0.6,
      tint: [_a(0, 0, 40, 0.35), _a(0, 0, 20, 0.8)], fx: MontageFx.moon, kick: 'Dans ma bulle', title: 'J’aime ma bulle', font: MontageFont.script,
      accent: const Color(0xFFFFFF), chip: '🌙 Calme et heureux(se)', sound: 'Nuit',
      texts: ['Je parle peu, je ressens beaucoup 🌙', 'Mon calme n’est pas de la faiblesse.']),
  MontageTemplate(id: 'vie_reinvente', cat: MontageCat.vie, name: 'Je me réinvente', sample: _p7, pos: MontagePos.top,
      tint: [_a(0, 0, 0, 0.05), _a(0, 0, 0, 0.6)], fx: MontageFx.rays, kick: 'Nouvelle version', title: 'Version 2.0', font: MontageFont.anton,
      accent: const Color(0xFFD400), chip: '🔄 Plus fort(e)', sound: 'Motivation',
      texts: ['Je me réinvente : nouvelle énergie, nouveaux objectifs 🔄', 'L’ancienne version a fait de son mieux, celle-ci va plus loin.']),
  MontageTemplate(id: 'vie_reussite', cat: MontageCat.vie, name: 'Ma réussite', sample: _p2, frame: MontageFrame.gold, saturation: 1.05,
      tint: [_a(255, 200, 0, 0.1), _a(60, 40, 0, 0.72)], fx: MontageFx.crown, kick: 'Victoire', title: 'J’ai réussi', font: MontageFont.anton,
      accent: const Color(0xFFD400), chip: '🏆 Merci Dieu', sound: 'Épique',
      texts: ['J’ai réussi : merci à ceux qui ont cru en moi 🏆', 'Pour ceux qui doutaient : regardez bien.']),
  MontageTemplate(id: 'amb_noir', cat: MontageCat.ambiances, name: 'Tout est noir', sample: _p4, saturation: 0.2, pos: MontagePos.center,
      tint: [_a(0, 0, 0, 0.35), _a(0, 0, 0, 0.86)], fx: MontageFx.rain, kick: 'Ce soir', title: 'Tout est noir', font: MontageFont.script,
      accent: const Color(0xFFFFFF), chip: '🖤 Je tiens', sound: 'Piano',
      texts: ['Parfois tout devient noir… et on avance quand même 🖤', 'Le silence aussi est une réponse.']),
  MontageTemplate(id: 'amb_solitude', cat: MontageCat.ambiances, name: 'Solitude', sample: _p5, pos: MontagePos.center, saturation: 0.45,
      tint: [_a(20, 30, 60, 0.3), _a(0, 0, 20, 0.8)], fx: MontageFx.cloud, kick: 'Seul(e)', title: 'Seul(e), mais debout', font: MontageFont.script,
      accent: const Color(0xFFFFFF), chip: '🌫️ En silence', sound: 'Piano',
      texts: ['Je suis seul(e) mais pas faible 🌫️', 'La solitude m’a appris à me suffire.']),
  MontageTemplate(id: 'amb_pluie', cat: MontageCat.ambiances, name: 'Jour de pluie', sample: _p3, pos: MontagePos.center, saturation: 0.45,
      tint: [_a(20, 30, 60, 0.3), _a(0, 0, 20, 0.8)], fx: MontageFx.rain, kick: 'Dehors', title: 'Il pleut… dedans aussi', font: MontageFont.script,
      accent: const Color(0xFFFFC9CED6), chip: '☔ Ça passera', sound: 'Piano',
      texts: ['Il pleut dehors, un peu dedans aussi ☔', 'Après la pluie, il y a toujours le soleil.']),
  MontageTemplate(id: 'amb_faux', cat: MontageCat.ambiances, name: 'Fatigué(e) de faire semblant', sample: _p4, pos: MontagePos.center, saturation: 0.2,
      tint: [_a(0, 0, 0, 0.35), _a(0, 0, 0, 0.86)], fx: MontageFx.none, kick: 'Honnêtement', title: 'Je suis fatigué(e) de faire semblant', font: MontageFont.anton,
      accent: const Color(0xFFFFFF), chip: '🎭 Assez', sound: 'Tension',
      texts: ['Fatigué(e) de sourire quand ça ne va pas 🎭', 'Je n’ai pas besoin de aller bien pour vous plaire.']),
  MontageTemplate(id: 'amb_dur', cat: MontageCat.ambiances, name: 'Les temps sont durs', sample: _p7, saturation: 0.8,
      tint: [_a(120, 0, 0, 0.2), _a(40, 0, 0, 0.78)], fx: MontageFx.storm, kick: 'Ces temps-ci', title: 'Les temps sont durs', font: MontageFont.anton,
      accent: const Color(0xFFFFFF), chip: '⛈️ Mais je reste debout', sound: 'Tension',
      texts: ['Les temps sont durs, mais je le suis encore plus ⛈️', 'Une tempête ne dure jamais toujours.']),
  MontageTemplate(id: 'amb_lumiere', cat: MontageCat.ambiances, name: 'Après la nuit, la lumière', sample: _p1, pos: MontagePos.top, saturation: 1.05,
      tint: [_a(255, 200, 0, 0.1), _a(60, 40, 0, 0.72)], fx: MontageFx.sunset, kick: 'Espoir', title: 'Après la nuit, la lumière', font: MontageFont.script,
      accent: const Color(0xFFD400), chip: '🌅 Ça vient', sound: 'Kalimba',
      texts: ['Après la nuit la plus noire vient toujours l’aube 🌅', 'Tiens bon, ton tour arrive.']),
  MontageTemplate(id: 'amb_joie', cat: MontageCat.ambiances, name: 'Joie pure', sample: _p2, frame: MontageFrame.wax, saturation: 1.15,
      tint: [_a(255, 200, 0, 0.08), _a(120, 40, 0, 0.55)], fx: MontageFx.confetti, kick: 'Aujourd’hui', title: 'Je suis heureux(se) !', font: MontageFont.anton,
      accent: const Color(0xFFD400), chip: '😄 Sans raison', sound: 'Afrobeat',
      texts: ['Aujourd’hui je suis heureux(se), sans raison, et c’est parfait 😄', 'La joie ne se mérite pas, elle se vit.']),
  MontageTemplate(id: 'amb_vie', cat: MontageCat.ambiances, name: 'La vie est belle', sample: _p6, saturation: 1.15,
      tint: [_a(255, 200, 0, 0.08), _a(120, 40, 0, 0.55)], fx: MontageFx.sparkle, kick: 'Respire', title: 'La vie est belle', font: MontageFont.script,
      accent: const Color(0xFFD400), chip: '🌍 Merci', sound: 'Highlife',
      texts: ['La vie est belle quand on sait regarder 🌍', 'Merci pour le soleil, la santé et ceux que j’aime.']),
  MontageTemplate(id: 'amb_liberte', cat: MontageCat.ambiances, name: 'Libre', sample: _p7, pos: MontagePos.top,
      tint: [_a(0, 0, 0, 0.05), _a(0, 0, 0, 0.6)], fx: MontageFx.speed, kick: 'Liberté', title: 'Libre comme l’air', font: MontageFont.anton,
      accent: const Color(0xFFFFFF), chip: '🕊️ Rien ne me retient', sound: 'Afrobeat',
      texts: ['Libre : de mes choix, de mes erreurs, de mon avenir 🕊️', 'Personne ne décide de ma vie à ma place.']),
  MontageTemplate(id: 'amb_envie', cat: MontageCat.ambiances, name: 'Ça donne envie de vivre', sample: _p1, saturation: 1.15,
      tint: [_a(255, 200, 0, 0.08), _a(120, 40, 0, 0.55)], fx: MontageFx.bokeh, kick: 'Envie', title: 'Envie de tout vivre', font: MontageFont.bold,
      accent: const Color(0xFFD400), chip: '🔥 Maintenant', sound: 'Amapiano',
      texts: ['Envie de partir, de rire, d’aimer, de réussir 🔥', 'La vie ne se reporte pas, elle se vit.']),
  MontageTemplate(id: 'amb_ambition', cat: MontageCat.ambiances, name: 'Je vise plus haut', sample: _p2, frame: MontageFrame.gold, pos: MontagePos.top, saturation: 1.05,
      tint: [_a(255, 200, 0, 0.1), _a(60, 40, 0, 0.72)], fx: MontageFx.rays, kick: 'Ambition', title: 'Je vise plus haut', font: MontageFont.anton,
      accent: const Color(0xFFD400), chip: '🚀 Sans limites', sound: 'Épique',
      texts: ['Je vise plus haut que leurs attentes 🚀', 'Mes rêves sont trop grands pour leurs petites opinions.']),
  MontageTemplate(id: 'amb_nuit', cat: MontageCat.ambiances, name: 'Nuit blanche', sample: _p4, saturation: 0.6,
      tint: [_a(0, 0, 40, 0.35), _a(0, 0, 20, 0.8)], fx: MontageFx.zzz, kick: 'Il est tard', title: 'Nuit blanche', font: MontageFont.script,
      accent: const Color(0xFFFFFF), chip: '🌙 Trop de pensées', sound: 'Nuit',
      texts: ['3 h du matin : les pensées font plus de bruit que le silence 🌙', 'Je pense à tout ce que je n’ai pas dit.']),
  MontageTemplate(id: 'amb_paix', cat: MontageCat.ambiances, name: 'Paix intérieure', sample: _p3, pos: MontagePos.center, saturation: 0.9,
      tint: [_a(0, 60, 80, 0.15), _a(0, 20, 40, 0.7)], fx: MontageFx.waves, kick: 'Respire', title: 'La paix avant tout', font: MontageFont.script,
      accent: const Color(0xFFFFFF), chip: '🌊 Calme', sound: 'Kalimba',
      texts: ['Je choisis la paix, pas le drame 🌊', 'Moins de bruit, plus de vie.']),
  MontageTemplate(id: 'amb_courage', cat: MontageCat.ambiances, name: 'Du courage', sample: _p7, pos: MontagePos.top, saturation: 0.8,
      tint: [_a(120, 0, 0, 0.2), _a(40, 0, 0, 0.78)], fx: MontageFx.fire, kick: 'Tiens bon', title: 'Du courage', font: MontageFont.anton,
      accent: const Color(0xFFD400), chip: '🔥 Je me relève', sound: 'Épique',
      texts: ['Tomber fait partie du chemin, se relever en est la preuve 🔥', 'Le courage, c’est avoir peur et y aller quand même.']),
  MontageTemplate(id: 'amb_renaissance', cat: MontageCat.ambiances, name: 'Renaissance', sample: _p1, saturation: 1.05,
      tint: [_a(255, 200, 0, 0.1), _a(60, 40, 0, 0.72)], fx: MontageFx.sparkle, kick: 'Nouveau chapitre', title: 'Je renais', font: MontageFont.script,
      accent: const Color(0xFFD400), chip: '✨ Plus fort(e)', sound: 'Kalimba',
      texts: ['Je renais de mes cendres, plus fort(e) qu’avant ✨', 'Un nouveau chapitre commence, et je tiens la plume.']),
  MontageTemplate(id: 'amb_manque_air', cat: MontageCat.ambiances, name: 'Besoin de respirer', sample: _p5, pos: MontagePos.center, saturation: 0.2,
      tint: [_a(0, 0, 0, 0.35), _a(0, 0, 0, 0.86)], fx: MontageFx.cloud, kick: 'Pause', title: 'J’ai besoin de respirer', font: MontageFont.script,
      accent: const Color(0xFFFFFF), chip: '🌫️ Laissez-moi', sound: 'Piano',
      texts: ['Besoin de silence, de distance et de calme 🌫️', 'Je ne disparais pas, je me retrouve.']),
  MontageTemplate(id: 'pen_jour', cat: MontageCat.pensees, name: 'Pensée du jour', sample: _p3, pos: MontagePos.center,
      tint: [_a(0, 0, 0, 0.05), _a(0, 0, 0, 0.6)], fx: MontageFx.none, kick: 'Pensée du jour', title: 'Ce que je retiens', font: MontageFont.script,
      accent: const Color(0xFFD400), chip: '💭 À méditer', sound: 'Kalimba',
      texts: ['La paix vaut mieux que raison.', 'On devient ce qu’on répète chaque jour.']),
  MontageTemplate(id: 'pen_nuit', cat: MontageCat.pensees, name: 'Pensée de nuit', sample: _p4, saturation: 0.6,
      tint: [_a(0, 0, 40, 0.35), _a(0, 0, 20, 0.8)], fx: MontageFx.moon, kick: 'Cette nuit', title: 'Je pense à…', font: MontageFont.script,
      accent: const Color(0xFFFFFF), chip: '🌙 Sans filtre', sound: 'Nuit',
      texts: ['La nuit, on dit la vérité qu’on cache le jour 🌙', 'Certaines personnes méritent des remerciements, d’autres du silence.']),
  MontageTemplate(id: 'pen_vie', cat: MontageCat.pensees, name: 'La vie, c’est…', sample: _p6, pos: MontagePos.center, saturation: 0.9,
      tint: [_a(0, 60, 80, 0.15), _a(0, 20, 40, 0.7)], fx: MontageFx.bokeh, kick: 'Réflexion', title: 'La vie, c’est…', font: MontageFont.script,
      accent: const Color(0xFFFFFF), chip: '🌍 Et toi ?', sound: 'Highlife',
      texts: ['La vie, c’est apprendre à perdre pour mieux gagner.', 'La vie, c’est ce qui arrive pendant qu’on fait des plans.']),
  MontageTemplate(id: 'pen_amour', cat: MontageCat.pensees, name: 'Pensée d’amour', sample: _p2,
      tint: [_a(255, 60, 120, 0.12), _a(120, 0, 40, 0.62)], fx: MontageFx.hearts, kick: 'Amour', title: 'L’amour, le vrai', font: MontageFont.script,
      accent: const Color(0xFFFFFFB3C7), chip: '❤️ Simple et vrai', sound: 'Love',
      texts: ['Le vrai amour ne fait pas de bruit, il rassure.', 'Aimer, c’est choisir la même personne chaque jour.']),
  MontageTemplate(id: 'pen_sagesse', cat: MontageCat.pensees, name: 'Sagesse africaine', sample: _p7, pos: MontagePos.center, saturation: 1.05,
      tint: [_a(255, 200, 0, 0.1), _a(60, 40, 0, 0.72)], fx: MontageFx.leaves, kick: 'Proverbe', title: 'Le sage dit…', font: MontageFont.script,
      accent: const Color(0xFFD400), chip: '🦁 Sagesse', sound: 'Kora',
      texts: ['Si tu veux aller vite, marche seul ; si tu veux aller loin, marchez ensemble.', 'Celui qui ne sait pas où il va doit se souvenir d’où il vient.']),
  MontageTemplate(id: 'pen_lecon', cat: MontageCat.pensees, name: 'Ce que la vie m’a appris', sample: _p5, pos: MontagePos.center, saturation: 0.45,
      tint: [_a(20, 30, 60, 0.3), _a(0, 0, 20, 0.8)], fx: MontageFx.cloud, kick: 'Leçon', title: 'Ce que la vie m’a appris', font: MontageFont.bold,
      accent: const Color(0xFFFFFF), chip: '📚 Pour toi aussi', sound: 'Piano',
      texts: ['Tout le monde n’a pas de bonnes intentions, mais chaque personne t’apprend quelque chose.', 'Je ne regrette pas, j’ai appris.']),
  MontageTemplate(id: 'pen_conseil', cat: MontageCat.pensees, name: 'Un conseil', sample: _p1, pos: MontagePos.top,
      tint: [_a(0, 0, 0, 0.05), _a(0, 0, 0, 0.6)], fx: MontageFx.rays, kick: 'Conseil du jour', title: 'Écoute-moi bien', font: MontageFont.bold,
      accent: const Color(0xFFD400), chip: '🧠 À retenir', sound: 'Motivation',
      texts: ['Protège ta paix, même de ceux que tu aimes.', 'Ne compare pas ton début au milieu des autres.']),
  MontageTemplate(id: 'pen_question', cat: MontageCat.pensees, name: 'Question du jour', sample: _p3, pos: MontagePos.top,
      tint: [_a(0, 0, 0, 0), _a(60, 0, 80, 0.62)], fx: MontageFx.sparkle, kick: 'Question', title: 'Et toi, tu en penses quoi ?', font: MontageFont.bold,
      accent: const Color(0xFFD400), chip: '💬 Réponds-moi', sound: 'Amapiano',
      texts: ['Si tu pouvais tout recommencer, que changerais-tu ?', 'Quel conseil donnerais-tu à ton toi d’il y a 5 ans ?']),
  MontageTemplate(id: 'pen_avis', cat: MontageCat.pensees, name: 'Je me fous de l’avis des gens', sample: _p2, pos: MontagePos.top, saturation: 0.8,
      tint: [_a(120, 0, 0, 0.2), _a(40, 0, 0, 0.78)], fx: MontageFx.fire, kick: 'Message', title: 'Je me fous de ce qu’ils pensent', font: MontageFont.anton,
      accent: const Color(0xFFD400), chip: '🚫 Mon choix', sound: 'Épique',
      texts: ['Je me fous de l’avis des gens : je vis ma vie, pas la leur 🚫', 'Ceux qui parlent ne payent pas mes factures.']),
  MontageTemplate(id: 'pen_haters', cat: MontageCat.pensees, name: 'Les haters', sample: _p7, pos: MontagePos.top, saturation: 0.8,
      tint: [_a(120, 0, 0, 0.2), _a(40, 0, 0, 0.78)], fx: MontageFx.crown, kick: 'À tous mes haters', title: 'Merci d’en parler', font: MontageFont.anton,
      accent: const Color(0xFFD400), chip: '👑 Grâce à vous', sound: 'Épique',
      texts: ['Merci aux haters : vous me faites de la publicité gratuite 👑', 'Parlez de moi, j’ai de belles choses à vous montrer.']),
  MontageTemplate(id: 'pen_rien_devoir', cat: MontageCat.pensees, name: 'Je ne dois rien à personne', sample: _p4, saturation: 0.2,
      tint: [_a(0, 0, 0, 0.35), _a(0, 0, 0, 0.86)], fx: MontageFx.none, kick: 'Mon droit', title: 'Je ne dois rien à personne', font: MontageFont.anton,
      accent: const Color(0xFFFFFF), chip: '✋ Point final', sound: 'Tension',
      texts: ['Je ne dois pas d’explications à ceux qui ne m’ont pas aidé(e).', 'Ma vie, mes règles, mon rythme.']),
  MontageTemplate(id: 'pen_comme_ca', cat: MontageCat.pensees, name: 'Je suis comme ça', sample: _p6, pos: MontagePos.center,
      tint: [_a(0, 0, 0, 0), _a(60, 0, 80, 0.62)], fx: MontageFx.sparkle, kick: 'Pour ceux qui n’aiment pas', title: 'Je suis comme ça', font: MontageFont.bold,
      accent: const Color(0xFFD400), chip: '💅 Et alors ?', sound: 'Amapiano',
      texts: ['Je suis comme ça : sincère, direct(e), pas pour tout le monde 💅', 'Si ça ne te plaît pas, tu n’es pas obligé(e) de rester.']),
  MontageTemplate(id: 'pen_silence', cat: MontageCat.pensees, name: 'Je ne réponds plus', sample: _p5, pos: MontagePos.center, saturation: 0.2,
      tint: [_a(0, 0, 0, 0.35), _a(0, 0, 0, 0.86)], fx: MontageFx.none, kick: 'Silence', title: 'Je ne réponds plus', font: MontageFont.script,
      accent: const Color(0xFFFFFF), chip: '🤐 Paix', sound: 'Piano',
      texts: ['Tout ne mérite pas une réponse 🤐', 'Le silence est la meilleure des réponses.']),
  MontageTemplate(id: 'pen_respect', cat: MontageCat.pensees, name: 'Respect', sample: _p7, frame: MontageFrame.gold, pos: MontagePos.top, saturation: 1.05,
      tint: [_a(255, 200, 0, 0.1), _a(60, 40, 0, 0.72)], fx: MontageFx.crown, kick: 'Règle d’or', title: 'Respecte-moi ou ignore-moi', font: MontageFont.anton,
      accent: const Color(0xFFD400), chip: '👑 Pas de milieu', sound: 'Épique',
      texts: ['Respecte-moi, ou ignore-moi : il n’y a pas de troisième option 👑', 'Je donne du respect, j’en attends autant.']),
  MontageTemplate(id: 'pen_progres', cat: MontageCat.pensees, name: 'Je progresse', sample: _p1,
      tint: [_a(0, 80, 40, 0.15), _a(0, 30, 20, 0.72)], fx: MontageFx.leaves, kick: 'Progrès', title: 'Petit à petit', font: MontageFont.bold,
      accent: const Color(0xFFFF7CE0A0), chip: '🌱 Chaque jour', sound: 'Kalimba',
      texts: ['Je ne suis pas encore là où je veux, mais plus là où j’étais 🌱', 'Les petits pas comptent aussi.']),
  MontageTemplate(id: 'pen_vrais', cat: MontageCat.pensees, name: 'Les vrais', sample: _p2, pos: MontagePos.center, saturation: 1.05,
      tint: [_a(255, 200, 0, 0.1), _a(60, 40, 0, 0.72)], fx: MontageFx.sparkle, kick: 'Pour mes proches', title: 'Les vrais se reconnaissent', font: MontageFont.script,
      accent: const Color(0xFFD400), chip: '🤝 Merci', sound: 'Highlife',
      texts: ['Les vrais se reconnaissent dans les moments difficiles 🤝', 'Peu de gens, mais des gens vrais.']),
  MontageTemplate(id: 'we_vendredi', cat: MontageCat.weekend, name: 'Vendredi soir', sample: _p3, pos: MontagePos.top,
      tint: [_a(0, 0, 0, 0), _a(60, 0, 80, 0.62)], fx: MontageFx.disco, kick: 'Enfin vendredi', title: 'Vendredi soir !', font: MontageFont.anton,
      accent: const Color(0xFFD400), chip: '🎉 Le weekend commence', sound: 'Amapiano',
      texts: ['Vendredi soir : le travail est derrière, la fête devant 🎉', 'Le weekend, c’est la meilleure mise à jour de la semaine.']),
  MontageTemplate(id: 'we_samedi', cat: MontageCat.weekend, name: 'Samedi, on sort', sample: _p6, frame: MontageFrame.wax, saturation: 1.15,
      tint: [_a(255, 200, 0, 0.08), _a(120, 40, 0, 0.55)], fx: MontageFx.disco, kick: 'Samedi', title: 'On sort ce soir ?', font: MontageFont.anton,
      accent: const Color(0xFFD400), chip: '🕺 On y va', sound: 'Coupé-décalé',
      texts: ['Samedi : tenue, parfum, bonne humeur 🕺', 'Ce soir, on oublie la semaine.']),
  MontageTemplate(id: 'we_dimanche', cat: MontageCat.weekend, name: 'Dimanche calme', sample: _p5, pos: MontagePos.top, saturation: 0.9,
      tint: [_a(0, 60, 80, 0.15), _a(0, 20, 40, 0.7)], fx: MontageFx.cloud, kick: 'Dimanche', title: 'Dimanche, calme et lenteur', font: MontageFont.script,
      accent: const Color(0xFFFFFF), chip: '☕ Rien à faire', sound: 'Kalimba',
      texts: ['Dimanche : café, silence et zéro pression ☕', 'Aujourd’hui, mon seul programme, c’est me reposer.']),
  MontageTemplate(id: 'we_fin', cat: MontageCat.weekend, name: 'Fin de weekend', sample: _p7, pos: MontagePos.center, saturation: 0.45,
      tint: [_a(20, 30, 60, 0.3), _a(0, 0, 20, 0.8)], fx: MontageFx.zzz, kick: 'Dimanche soir', title: 'Déjà lundi demain ?', font: MontageFont.bold,
      accent: const Color(0xFFFFFF), chip: '😩 Pas prêt(e)', sound: 'Nuit',
      texts: ['Dimanche soir : mon cerveau a déjà commencé la semaine 😩', 'Le weekend passe trop vite, le lundi trop lentement.']),
  MontageTemplate(id: 'we_match', cat: MontageCat.weekend, name: 'Jour de match', sample: _p2,
      tint: [_a(0, 80, 40, 0.15), _a(0, 30, 20, 0.72)], fx: MontageFx.fire, kick: 'Ce soir', title: 'Jour de match !', font: MontageFont.anton,
      accent: const Color(0xFFD400), chip: '⚽ Allez !', sound: 'Fanfare',
      texts: ['Jour de match : le cœur bat, la voix est prête ⚽', 'Nos couleurs, notre fierté.']),
  MontageTemplate(id: 'we_detente', cat: MontageCat.weekend, name: 'Détente', sample: _p1, pos: MontagePos.top, saturation: 0.9,
      tint: [_a(0, 60, 80, 0.15), _a(0, 20, 40, 0.7)], fx: MontageFx.waves, kick: 'Pause', title: 'Je me repose', font: MontageFont.script,
      accent: const Color(0xFFFFFF), chip: '🌴 Zéro stress', sound: 'Plage',
      texts: ['Weekend détente : télé éteinte, esprit tranquille 🌴', 'Je recharge mes batteries, à lundi.']),
  MontageTemplate(id: 'ev_soiree', cat: MontageCat.evenements, name: 'Soirée', sample: _p3, saturation: 0.6,
      tint: [_a(0, 0, 40, 0.35), _a(0, 0, 20, 0.8)], fx: MontageFx.disco, kick: 'Save the date', title: 'Soirée à ne pas manquer', font: MontageFont.anton,
      accent: const Color(0xFFD400), chip: '🎶 Venez nombreux', sound: 'Coupé-décalé',
      texts: ['Ambiance, musique et bonne humeur : on vous attend 🎶', 'Une soirée dont on parlera longtemps !'],
      presetWidgets: () => [PostWidget(kind: WidgetKind.countdown, config: {'title': 'Début de la soirée', 'at': montageInDays(5, 21)}, x: .5, y: 0.26), PostWidget(kind: WidgetKind.place, config: {'name': 'Lieu de la soirée', 'maps_url': ''}, x: .5, y: 0.6)]),
  MontageTemplate(id: 'ev_concert', cat: MontageCat.evenements, name: 'Concert', sample: _p2, saturation: 0.6,
      tint: [_a(0, 0, 40, 0.35), _a(0, 0, 20, 0.8)], fx: MontageFx.disco, kick: 'En concert', title: 'Le concert approche', font: MontageFont.anton,
      accent: const Color(0xFFD400), chip: '🎤 Réservez', sound: 'Afrobeat',
      texts: ['Le concert de l’année, ne soyez pas absents 🎤', 'Les places partent vite !'],
      presetWidgets: () => [PostWidget(kind: WidgetKind.countdown, config: {'title': 'Ouverture des portes', 'at': montageInDays(14, 18)}, x: .5, y: 0.26), PostWidget(kind: WidgetKind.place, config: {'name': 'Salle du concert', 'maps_url': ''}, x: .5, y: 0.6)]),
  MontageTemplate(id: 'ev_inaug', cat: MontageCat.evenements, name: 'Inauguration', sample: _p1, saturation: 1.05,
      tint: [_a(255, 200, 0, 0.1), _a(60, 40, 0, 0.72)], fx: MontageFx.crown, kick: 'Grande ouverture', title: 'On ouvre nos portes', font: MontageFont.anton,
      accent: const Color(0xFFD400), chip: '🎀 Venez découvrir', sound: 'Fanfare',
      texts: ['Après des mois de travail, nous ouvrons enfin ! 🎀', 'Venez nous soutenir à l’inauguration.'],
      presetWidgets: () => [PostWidget(kind: WidgetKind.countdown, config: {'title': 'Inauguration', 'at': montageInDays(10, 10)}, x: .5, y: 0.26), PostWidget(kind: WidgetKind.place, config: {'name': 'Adresse', 'maps_url': ''}, x: .5, y: 0.6)]),
  MontageTemplate(id: 'ev_invit', cat: MontageCat.evenements, name: 'Invitation', sample: _p6,
      tint: [_a(255, 60, 120, 0.12), _a(120, 0, 40, 0.62)], fx: MontageFx.sparkle, kick: 'Vous êtes invités', title: 'Tu viens ?', font: MontageFont.script,
      accent: const Color(0xFFFFFFB3C7), chip: '💌 Dis-moi vite', sound: 'Highlife',
      texts: ['Je t’invite à partager ce moment avec moi 💌', 'Ta présence me ferait vraiment plaisir.'],
      presetWidgets: () => [PostWidget(kind: WidgetKind.poll, config: {'question': 'Tu viens ?', 'options': ['Oui !', 'Je ne peux pas', 'Je ne sais pas encore']}, x: .5, y: 0.62), PostWidget(kind: WidgetKind.place, config: {'name': 'Lieu', 'maps_url': ''}, x: .5, y: 0.8)]),
  MontageTemplate(id: 'ev_conf', cat: MontageCat.evenements, name: 'Conférence, formation', sample: _p4,
      tint: [_a(0, 0, 0, 0.05), _a(0, 0, 0, 0.6)], fx: MontageFx.rays, kick: 'Formation', title: 'Une formation à ne pas rater', font: MontageFont.bold,
      accent: const Color(0xFFD400), chip: '🎓 Places limitées', sound: 'Motivation',
      texts: ['Apprenez, échangez, progressez avec nous 🎓', 'Inscrivez-vous avant la fin des places.'],
      presetWidgets: () => [PostWidget(kind: WidgetKind.countdown, config: {'title': 'Début', 'at': montageInDays(12, 9)}, x: .5, y: 0.26), PostWidget(kind: WidgetKind.place, config: {'name': 'Lieu', 'maps_url': ''}, x: .5, y: 0.6)]),
  MontageTemplate(id: 'ev_flash', cat: MontageCat.evenements, name: 'Vente flash', sample: _p7, saturation: 0.8,
      tint: [_a(120, 0, 0, 0.2), _a(40, 0, 0, 0.78)], fx: MontageFx.fire, kick: 'Promo', title: 'Vente flash !', font: MontageFont.anton,
      accent: const Color(0xFFD400), chip: '🏷️ Jusqu’à -50 %', sound: 'Coupé-décalé',
      texts: ['Vente flash : stock limité, prix cassés 🏷️', 'Dépêchez-vous, ça se termine bientôt !'],
      presetWidgets: () => [PostWidget(kind: WidgetKind.countdown, config: {'title': 'Fin de la promo', 'at': montageInDays(3, 23)}, x: .5, y: 0.26)]),
  MontageTemplate(id: 'ev_famille', cat: MontageCat.evenements, name: 'Réunion de famille', sample: _p6, saturation: 1.15,
      tint: [_a(255, 200, 0, 0.08), _a(120, 40, 0, 0.55)], fx: MontageFx.hearts, kick: 'Retrouvailles', title: 'Tous ensemble', font: MontageFont.script,
      accent: const Color(0xFFD400), chip: '👨‍👩‍👧‍👦 On compte sur vous', sound: 'Highlife',
      texts: ['Une journée pour se retrouver, rire et manger ensemble 👨‍👩‍👧‍👦', 'La famille, c’est la plus belle des fêtes.'],
      presetWidgets: () => [PostWidget(kind: WidgetKind.countdown, config: {'title': 'Le grand rassemblement', 'at': montageInDays(20, 12)}, x: .5, y: 0.26), PostWidget(kind: WidgetKind.place, config: {'name': 'Lieu', 'maps_url': ''}, x: .5, y: 0.6)]),
  MontageTemplate(id: 'ev_bapteme', cat: MontageCat.evenements, name: 'Baptême, communion', sample: _p6,
      tint: [_a(0, 0, 0, 0.05), _a(0, 0, 0, 0.6)], fx: MontageFx.sparkle, kick: 'Célébration', title: 'Un jour béni', font: MontageFont.script,
      accent: const Color(0xFFFFFF), chip: '🙏 Partageons la joie', sound: 'Louange',
      texts: ['Nous célébrons ce jour béni avec vous 🙏', 'Votre présence est notre plus beau cadeau.'],
      presetWidgets: () => [PostWidget(kind: WidgetKind.countdown, config: {'title': 'La cérémonie', 'at': montageInDays(21, 10)}, x: .5, y: 0.26), PostWidget(kind: WidgetKind.place, config: {'name': 'Lieu', 'maps_url': ''}, x: .5, y: 0.6)]),
  MontageTemplate(id: 'fe_blackfriday', cat: MontageCat.fetes, name: 'Black Friday', sample: _p7, saturation: 0.2,
      tint: [_a(0, 0, 0, 0.35), _a(0, 0, 0, 0.86)], fx: MontageFx.fire, kick: 'Les prix tombent', title: 'Black Friday', font: MontageFont.anton,
      accent: const Color(0xFFD400), chip: '🛒 Les meilleures offres', sound: 'Coupé-décalé',
      texts: ['Black Friday : les meilleures offres de l’année 🛒', 'Ne ratez pas les prix qui chutent !']),
  MontageTemplate(id: 'fe_rentree', cat: MontageCat.fetes, name: 'Rentrée scolaire', sample: _p4,
      tint: [_a(0, 0, 0, 0.05), _a(0, 0, 0, 0.6)], fx: MontageFx.rays, kick: 'Rentrée', title: 'C’est la rentrée !', font: MontageFont.bold,
      accent: const Color(0xFFD400), chip: '🎒 Cahiers, stylos, courage', sound: 'Motivation',
      texts: ['Bonne rentrée à tous les élèves, parents et enseignants 🎒', 'Nouvelle année, nouveaux objectifs !']),
  MontageTemplate(id: 'fe_musique', cat: MontageCat.fetes, name: 'Fête de la musique', sample: _p3,
      tint: [_a(0, 0, 0, 0), _a(60, 0, 80, 0.62)], fx: MontageFx.disco, kick: 'Fête de la musique', title: 'Que la musique commence', font: MontageFont.anton,
      accent: const Color(0xFFD400), chip: '🎵 Partout', sound: 'Afrobeat',
      texts: ['La musique rassemble, la musique guérit 🎵', 'Aujourd’hui, tout le monde danse !']),
  MontageTemplate(id: 'fe_halloween', cat: MontageCat.fetes, name: 'Halloween', sample: _p4, saturation: 0.2,
      tint: [_a(0, 0, 0, 0.35), _a(0, 0, 0, 0.86)], fx: MontageFx.moon, kick: 'Cette nuit', title: 'Joyeux Halloween', font: MontageFont.anton,
      accent: const Color(0xFFFFFF9A3C), chip: '🎃 Bonbons ou sort ?', sound: 'Tension',
      texts: ['Cette nuit, on se déguise et on fait peur 🎃', 'Qui sera le plus effrayant ce soir ?']),
  MontageTemplate(id: 'fe_sylvestre', cat: MontageCat.fetes, name: 'Saint-Sylvestre', sample: _p3, saturation: 0.6,
      tint: [_a(0, 0, 40, 0.35), _a(0, 0, 20, 0.8)], fx: MontageFx.fireworks, kick: '31 décembre', title: 'Dernière nuit de l’année', font: MontageFont.anton,
      accent: const Color(0xFFD400), chip: '🥂 À minuit', sound: 'Fête',
      texts: ['Ce soir, on dit au revoir à $_endingYear en beauté 🥂', 'Cinq, quatre, trois, deux, un… Bonne année !'],
      presetWidgets: () => [PostWidget(kind: WidgetKind.countdown, config: {'title': 'Minuit', 'at': _newYearEve()}, x: .5, y: 0.26)]),
  MontageTemplate(id: 'dr_realite', cat: MontageCat.droles, name: 'Moi vs la réalité', sample: _p3, pos: MontagePos.top, dualSample: _p5,
      tint: [_a(0, 0, 0, 0), _a(60, 0, 80, 0.62)], fx: MontageFx.none, kick: 'Attente / Réalité', title: 'Moi vs la réalité', font: MontageFont.anton,
      accent: const Color(0xFFD400), chip: '😂 La différence', sound: 'Comique',
      texts: ['Ce que je pensais faire / ce que ça a donné 😂', 'Moi : confiant(e). La réalité : non.']),
  MontageTemplate(id: 'dr_salaire', cat: MontageCat.droles, name: 'Avant / après le salaire', sample: _p7, pos: MontagePos.top, dualSample: _p2,
      tint: [_a(0, 0, 0, 0), _a(60, 0, 80, 0.62)], fx: MontageFx.money, kick: 'Le 29 / le 30', title: 'La vie change en 24 h', font: MontageFont.anton,
      accent: const Color(0xFFD400), chip: '💰 0 FCFA → 150 000 FCFA', sound: 'Coupé-décalé',
      texts: ['Le 29 : pas un franc. Le 30 : roi / reine du quartier 💰', 'Mon portefeuille et moi, on a une relation compliquée.']),
  MontageTemplate(id: 'dr_note', cat: MontageCat.droles, name: 'Note du jour sur 10', sample: _p3, pos: MontagePos.center,
      tint: [_a(0, 0, 0, 0), _a(60, 0, 80, 0.62)], fx: MontageFx.sparkle, kick: 'Note du jour', title: '8/10', font: MontageFont.anton,
      accent: const Color(0xFFD400), chip: '★★★★★★★★☆☆', sound: 'Amapiano',
      texts: ['Ma journée en un mot : « Ça va »', 'Journée notée 8/10 : il manquait juste un café ☕'],
      presetWidgets: () => [PostWidget(kind: WidgetKind.reaction, config: {'question': 'Donne ta note ↑', 'emojis': ['❤️', '🔥', '😂', '😮', '😢', '👏']}, x: .5, y: 0.8)]),

  MontageTemplate(id: 'dr_pov', cat: MontageCat.droles, name: 'POV…', sample: _p4, pos: MontagePos.top, saturation: 0.2,
      tint: [_a(0, 0, 0, 0.35), _a(0, 0, 0, 0.86)], fx: MontageFx.none, kick: 'POV', title: 'POV : tu es moi un lundi', font: MontageFont.anton,
      accent: const Color(0xFFD400), chip: '🎬 Sans commentaire', sound: 'Tension',
      texts: ['POV : tu dis « je dors tôt » et il est 3 h du matin', 'POV : tu fais semblant de comprendre la réunion.']),
  MontageTemplate(id: 'dr_maman', cat: MontageCat.droles, name: 'Quand maman appelle', sample: _p6,
      tint: [_a(0, 0, 0, 0), _a(60, 0, 80, 0.62)], fx: MontageFx.speed, kick: 'Urgent', title: 'Quand maman appelle…', font: MontageFont.anton,
      accent: const Color(0xFFD400), chip: '📞 Je décroche ?', sound: 'Comique',
      texts: ['Quand maman appelle trois fois de suite : qu’est-ce que j’ai fait ? 📞', 'Maman : « Je voulais juste dire bonjour ». Mon cœur : ouf.']),
  MontageTemplate(id: 'dr_wifi', cat: MontageCat.droles, name: 'Le wifi qui coupe', sample: _p5, pos: MontagePos.top, saturation: 0.2,
      tint: [_a(0, 0, 0, 0.35), _a(0, 0, 0, 0.86)], fx: MontageFx.cloud, kick: 'Drame', title: 'Le wifi vient de couper', font: MontageFont.anton,
      accent: const Color(0xFFFFFF6A6A), chip: '📶 Pourquoi maintenant', sound: 'Tension',
      texts: ['Le wifi coupe au moment le plus important, évidemment 📶', 'Mon calme : 100 %. Mon réseau : 0 %.']),
  MontageTemplate(id: 'dr_ne_ris_pas', cat: MontageCat.droles, name: 'Défi : ne ris pas', sample: _p3, pos: MontagePos.center,
      tint: [_a(0, 0, 0, 0), _a(60, 0, 80, 0.62)], fx: MontageFx.confetti, kick: 'Défi', title: 'Ne ris pas !', font: MontageFont.anton,
      accent: const Color(0xFFD400), chip: '😂 Tu tiens combien ?', sound: 'Comique',
      texts: ['Défi : ne pas rire pendant 10 secondes 😂', 'Qui a craqué ? Dis-le en commentaire.'],
      presetWidgets: () => [PostWidget(kind: WidgetKind.poll, config: {'question': 'Tu as ri ?', 'options': ['Oui 😂', 'Non, je tiens !']}, x: .5, y: 0.72)]),

  MontageTemplate(id: 'dr_entendu', cat: MontageCat.droles, name: 'Ce que j’ai dit / ce qu’ils ont entendu', sample: _p2, dualSample: _p6,
      tint: [_a(0, 0, 0, 0), _a(60, 0, 80, 0.62)], fx: MontageFx.none, kick: 'Malentendu', title: 'J’ai dit… ils ont entendu…', font: MontageFont.anton,
      accent: const Color(0xFFD400), chip: '🗣️ Incompréhension', sound: 'Comique',
      texts: ['Ce que j’ai dit : « je suis fatigué(e) ». Ce qu’ils ont entendu : « venez me parler ».', 'Moi : « on se voit bientôt ». Eux : « demain à 7 h ».']),
  MontageTemplate(id: 'dr_regime', cat: MontageCat.droles, name: 'Le régime', sample: _p4, pos: MontagePos.top,
      tint: [_a(0, 0, 0, 0), _a(60, 0, 80, 0.62)], fx: MontageFx.none, kick: 'Lundi prochain', title: 'Je commence le régime lundi', font: MontageFont.anton,
      accent: const Color(0xFFD400), chip: '🍟 Peut-être pas', sound: 'Comique',
      texts: ['Je commence le régime lundi (depuis trois ans) 🍟', 'Salade au bureau, pizza à la maison : équilibre parfait.']),
  MontageTemplate(id: 'dr_selfie', cat: MontageCat.droles, name: 'Selfie raté', sample: _p5,
      tint: [_a(0, 0, 0, 0), _a(60, 0, 80, 0.62)], fx: MontageFx.sparkle, kick: 'Photo', title: 'Ceci est mon meilleur profil', font: MontageFont.bold,
      accent: const Color(0xFFD400), chip: '🤳 Je n’en ai qu’un', sound: 'Amapiano',
      texts: ['Mon meilleur profil ? Celui que je n’ai pas montré 🤳', 'Trente photos, une seule présentable.']),
];

/// Musiques libres de droits (Kevin MacLeod, CC BY 4.0) proposées d'office à la place des pistes d'Afrolook pour les modèles qu'elles illustrent mieux : courage, amour, tristesse, fêtes,
/// fin d'année, humour… (id de [kStudioTracks]). Un modèle absent d'ici garde la piste de [kTemplateMusic].
const Map<String, String> kTemplateMusicLibre = {
  // fêtes
  'nouvelan': 'celebration', 'noel': 'we_wish_you_a_merry_christmas', 'valentin': 'what_is_love', 'fe_halloween': 'danse_macabre', 'fe_sylvestre': 'beachfront_celebration',
  'ramadan': 'desert_city', 'tabaski': 'tabuk', 'anniv': 'disco_con_tutti', 'anniv_minuteur': 'celebration', 'meres': 'reawakening',
  'ev_soiree': 'disco_con_tutti', 'ev_inaug': 'heroic_age', 'ev_bapteme': 'amazing_grace_2011', 'ev_famille': 'fireflies_and_stardust',
  // fin d'année
  'gen_journee': 'morning', 'gen_weekend': 'carefree', 'gen_histoire': 'long_road_ahead', 'gen_anniv': 'celebration', 'gen_voyage': 'inspired', 'gen_soiree': 'disco_con_tutti', 'gen_mariage': 'canon_in_d_for_two_harps',
  'gen_business': 'motivator', 'gen_famille': 'fireflies_and_stardust',
  'fa_film': 'eternal_hope', 'fa_triomphe': 'despair_and_triumph', 'fa_merci': 'reawakening', 'fa_page': 'danse_morialta', 'fa_change': 'frost_waltz_alternate',
  'fa_bilan': 'immersed', 'fa_lecons': 'aretes', 'fa_resolutions': 'motivator',
  // vie, duos et collages
  'duo_reaction': 'monkeys_spinning_monkeys', 'duo_cote': 'mischief_maker', 'duo_avant_apres_video': 'motivator', 'multi_avant_apres': 'motivator', 'multi_duo': 'what_is_love',
  'multi_toi_lui': 'happy_happy_game_show', 'multi_boutique': 'carefree', 'multi_recette': 'jazz_brunch', 'multi_cinq_moments': 'eternal_hope', 'multi_quatre_saisons': 'morning', 'vie_chemin': 'long_road_ahead', 'vie_hommage': 'lost_time', 'vie_mariage': 'canon_in_d_for_two_harps',
  'vie_bebe': 'dreamer', 'vie_famille': 'fireflies_and_stardust', 'vie_combat': 'undaunted', 'vie_reussite': 'heroic_age', 'vie_devenu': 'our_story_begins',
  'vie_objectifs': 'motivator', 'vie_reinvente': 'eternal_hope', 'vie_retrouv': 'reawakening',
  // ambiances
  'amb_noir': 'colorless_aura', 'amb_solitude': 'heavy_heart', 'amb_pluie': 'shores_of_avalon', 'amb_faux': 'man_down', 'amb_dur': 'dark_fog', 'amb_lumiere': 'eternal_hope',
  'amb_nuit': 'late_night_radio', 'amb_paix': 'airship_serenity', 'amb_courage': 'undaunted', 'amb_renaissance': 'morning', 'amb_ambition': 'heroic_age',
  // situations, émotions, pensées, week-end
  'separation': 'heavy_heart', 'trahi': 'lost_time', 'fiance': 'canon_in_d_for_two_harps', 'amour': 'what_is_love', 'triste': 'heavy_heart', 'nostalgie': 'danse_morialta', 'pardon': 'aretes',
  'pen_silence': 'immersed', 'pen_sagesse': 'aretes', 'pen_nuit': 'late_night_radio', 'we_dimanche': 'jazz_brunch', 'we_vendredi': 'disco_con_tutti', 'we_samedi': 'allada',
  // drôles
  'dr_realite': 'monkeys_spinning_monkeys', 'dr_salaire': 'darxieland', 'dr_note': 'happy_happy_game_show', 'dr_pov': 'mystery_bazaar', 'dr_maman': 'mischief_maker',
  'dr_wifi': 'sergios_magic_dustbin', 'dr_ne_ris_pas': 'the_entertainer', 'dr_regime': 'mischief_maker',
};

/// Musique gratuite proposée par défaut pour chaque template (id de [kStudioTracks]).
const Map<String, String> kTemplateMusic = {
  'fauche': 'coupe_decale', 'amour': 'love_afro', 'boss': 'afro_trap', 'separation': 'piano_triste', 'celib': 'amapiano',
  'goumin': 'tension', 'justebien': 'kora_calme', 'fiance': 'love_afro', 'parent': 'berceuse', 'trahi': 'piano_triste',
  'enfeu': 'afrobeat', 'goodvibes': 'highlife', 'enforme': 'workout', 'humeur': 'coupe_decale', 'pasforme': 'nuit',
  'epuise': 'nuit', 'zen': 'zen_kalimba', 'queen': 'afro_trap', 'triste': 'piano_triste', 'manque': 'love_afro',
  'gratitude': 'kora_calme', 'beni': 'kora_calme', 'motive': 'workout', 'fier': 'afro_trap', 'choque': 'tension',
  'colere': 'tension', 'stresse': 'tension', 'nostalgie': 'piano_triste', 'crush': 'love_afro', 'pardon': 'piano_triste',
  'hate': 'coupe_decale',
  'ootd': 'amapiano', 'selfie': 'amapiano', 'tbt': 'highlife', 'weekend': 'coupe_decale', 'lundi': 'workout',
  'vibe': 'amapiano', 'miam': 'highlife', 'voyage': 'plage', 'avis': 'afrobeat',
  'pays': 'highlife', 'marche': 'afrobeat', 'plage': 'plage', 'afrobeat': 'afrobeat', 'savane': 'kora_calme',
  'indep': 'fanfare', 'nouvelan': 'fanfare', 'ramadan': 'oud', 'noel': 'noel', 'valentin': 'love_afro', 'dragon_feu': 'tension', 'anniv': 'highlife', 'anniv_minuteur': 'highlife', 'evenement': 'afrobeat',
  'diplome': 'fanfare', 'nouveaujob': 'afrobeat',
  'chanson': 'afrobeat', 'dedicace': 'love_afro', 'soiree': 'amapiano', 'chill': 'nuit', 'louange': 'kora_calme', 'freestyle': 'afro_trap',
  'danse': 'coupe_decale', 'slow': 'love_afro', 'concert': 'afrobeat', 'oldschool': 'highlife', 'studio': 'afro_trap', 'sortie': 'afrobeat', 'focus': 'zen_kalimba',
  'paques': 'noel', 'meres': 'love_afro', 'peres': 'highlife', 'femmes': 'amapiano', 'afrique': 'highlife', 'tabaski': 'oud', 'travail': 'workout',
  'fa_film': 'kora_calme', 'fa_triomphe': 'afro_trap', 'fa_merci': 'kora_calme', 'fa_page': 'piano_triste', 'fa_change': 'fanfare', 'fa_bilan': 'highlife', 'fa_lecons': 'zen_kalimba', 'fa_resolutions': 'workout', 'vie_moi': 'zen_kalimba', 'vie_devenu': 'afro_trap', 'vie_chemin': 'piano_triste', 'vie_bebe': 'berceuse', 'vie_mariage': 'love_afro', 'vie_maison': 'highlife', 'vie_premier': 'workout', 'vie_voyage': 'plage', 'vie_hommage': 'piano_triste', 'vie_retrouv': 'highlife', 'vie_combat': 'tension', 'vie_objectifs': 'workout', 'vie_famille': 'love_afro', 'vie_age': 'zen_kalimba', 'vie_signe': 'amapiano', 'vie_introvertie': 'nuit', 'vie_reinvente': 'workout', 'vie_reussite': 'afro_trap', 'amb_noir': 'piano_triste', 'amb_solitude': 'piano_triste', 'amb_pluie': 'piano_triste', 'amb_faux': 'tension', 'amb_dur': 'tension', 'amb_lumiere': 'zen_kalimba', 'amb_joie': 'afrobeat', 'amb_vie': 'highlife', 'amb_liberte': 'afrobeat', 'amb_envie': 'amapiano', 'amb_ambition': 'afro_trap', 'amb_nuit': 'nuit', 'amb_paix': 'zen_kalimba', 'amb_courage': 'afro_trap', 'amb_renaissance': 'kora_calme', 'amb_manque_air': 'piano_triste', 'pen_jour': 'zen_kalimba', 'pen_nuit': 'nuit', 'pen_vie': 'highlife', 'pen_amour': 'love_afro', 'pen_sagesse': 'kora_calme', 'pen_lecon': 'piano_triste', 'pen_conseil': 'workout', 'pen_question': 'amapiano', 'pen_avis': 'afro_trap', 'pen_haters': 'afro_trap', 'pen_rien_devoir': 'tension', 'pen_comme_ca': 'amapiano', 'pen_silence': 'piano_triste', 'pen_respect': 'afro_trap', 'pen_progres': 'zen_kalimba', 'pen_vrais': 'highlife', 'we_vendredi': 'amapiano', 'we_samedi': 'coupe_decale', 'we_dimanche': 'zen_kalimba', 'we_fin': 'nuit', 'we_match': 'fanfare', 'we_detente': 'plage', 'ev_soiree': 'coupe_decale', 'ev_concert': 'afrobeat', 'ev_inaug': 'fanfare', 'ev_invit': 'highlife', 'ev_conf': 'workout', 'ev_flash': 'coupe_decale', 'ev_famille': 'highlife', 'ev_bapteme': 'kora_calme', 'fe_blackfriday': 'coupe_decale', 'fe_rentree': 'workout', 'fe_musique': 'afrobeat', 'fe_halloween': 'tension', 'fe_sylvestre': 'fanfare', 'dr_realite': 'coupe_decale', 'dr_salaire': 'coupe_decale', 'dr_note': 'amapiano', 'dr_pov': 'tension', 'dr_maman': 'coupe_decale', 'dr_wifi': 'tension', 'dr_ne_ris_pas': 'amapiano', 'dr_entendu': 'coupe_decale', 'dr_regime': 'coupe_decale', 'dr_selfie': 'amapiano',
};

/// Pays africains : affichés en premier dans le sélecteur.
const kAfricaCodes = {
  'DZ', 'AO', 'BJ', 'BW', 'BF', 'BI', 'CV', 'CM', 'CF', 'TD', 'KM', 'CG', 'CD', 'CI', 'DJ', 'EG', 'GQ', 'ER', 'SZ', 'ET', 'GA', 'GM', 'GH', 'GN', 'GW', 'KE', 'LS',
  'LR', 'LY', 'MG', 'MW', 'ML', 'MR', 'MU', 'MA', 'MZ', 'NA', 'NE', 'NG', 'RW', 'ST', 'SN', 'SC', 'SL', 'SO', 'ZA', 'SS', 'SD', 'TZ', 'TG', 'TN', 'UG', 'ZM', 'ZW',
};

/// Fête par pays : (jour, mois, année ou null, true = indépendance / false = fête nationale).
/// Un pays absent : la personne choisit le type de fête et la date.
const Map<String, (int, int, int?, bool)> kNationalDays = {
  'DZ': (5, 7, 1962, true), 'AO': (11, 11, 1975, true), 'BJ': (1, 8, 1960, true), 'BW': (30, 9, 1966, true), 'BF': (5, 8, 1960, true),
  'BI': (1, 7, 1962, true), 'CV': (5, 7, 1975, true), 'CM': (20, 5, null, false), 'CF': (13, 8, 1960, true), 'TD': (11, 8, 1960, true),
  'KM': (6, 7, 1975, true), 'CG': (15, 8, 1960, true), 'CD': (30, 6, 1960, true), 'CI': (7, 8, 1960, true), 'DJ': (27, 6, 1977, true),
  'EG': (23, 7, null, false), 'GQ': (12, 10, 1968, true), 'ER': (24, 5, 1993, true), 'SZ': (6, 9, 1968, true), 'GA': (17, 8, 1960, true),
  'GM': (18, 2, 1965, true), 'GH': (6, 3, 1957, true), 'GN': (2, 10, 1958, true), 'GW': (24, 9, 1973, true), 'KE': (12, 12, 1963, true),
  'LS': (4, 10, 1966, true), 'LR': (26, 7, 1847, true), 'LY': (24, 12, 1951, true), 'MG': (26, 6, 1960, true), 'MW': (6, 7, 1964, true),
  'ML': (22, 9, 1960, true), 'MR': (28, 11, 1960, true), 'MU': (12, 3, 1968, true), 'MA': (18, 11, null, true), 'MZ': (25, 6, 1975, true),
  'NA': (21, 3, 1990, true), 'NE': (3, 8, 1960, true), 'NG': (1, 10, 1960, true), 'RW': (1, 7, 1962, true), 'ST': (12, 7, 1975, true),
  'SN': (4, 4, 1960, true), 'SC': (29, 6, 1976, true), 'SL': (27, 4, 1961, true), 'SO': (1, 7, 1960, true), 'ZA': (27, 4, null, false),
  'SS': (9, 7, 2011, true), 'SD': (1, 1, 1956, true), 'TZ': (9, 12, 1961, true), 'TG': (27, 4, 1960, true), 'TN': (20, 3, 1956, true),
  'UG': (9, 10, 1962, true), 'ZM': (24, 10, 1964, true), 'ZW': (18, 4, 1980, true),
  'HT': (1, 1, 1804, true), 'FR': (14, 7, null, false), 'BE': (21, 7, null, false), 'CH': (1, 8, null, false), 'CA': (1, 7, null, false),
  'US': (4, 7, 1776, true), 'BR': (7, 9, 1822, true), 'MX': (16, 9, 1810, true), 'DE': (3, 10, null, false), 'IT': (2, 6, null, false),
  'ES': (12, 10, null, false), 'PT': (10, 6, null, false), 'CN': (1, 10, null, false), 'IN': (15, 8, 1947, true), 'JM': (6, 8, 1962, true),
  'LB': (22, 11, 1943, true),
};

const _mois = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];

String montageDayLabel(int day, int month) => '${day == 1 ? '1er' : day} ${_mois[month - 1]}';
