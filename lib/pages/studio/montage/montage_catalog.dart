// Catalogue des templates « prêts à poster » du Studio : chaque template arrive déjà rempli
// (photo d'exemple, sur-titre, titre, texte de souhait, badge, effet) ; la personne remplace ce qu'elle veut.

import 'package:flutter/material.dart';

enum MontageCat { situations, emotions, culture, fetes }

extension MontageCatX on MontageCat {
  String get label => switch (this) {
        MontageCat.situations => '😂 Situations',
        MontageCat.emotions => '💫 Émotions',
        MontageCat.culture => '🌍 Culture',
        MontageCat.fetes => '🎊 Fêtes',
      };
}

enum MontageFx { none, money, hearts, coins, rain, storm, cloud, sparkle, fire, rays, speed, bokeh, zzz, leaves, crown, waves, disco, sunset, fireworks, moon, snow, confetti, ring, baby }

enum MontageFont { bold, anton, script }

enum MontagePos { top, center, bottom }

enum MontageFrame { none, wax, gold }

/// Éléments que la personne peut retirer du montage. Le filigrane « Créé sur Afrolook » n'en fait pas partie : il reste toujours.
enum MontageLayer { kick, title, wish, chip, brand, pseudo, fx, frame, tint, flag }

extension MontageLayerX on MontageLayer {
  String get label => switch (this) {
        MontageLayer.kick => 'Sur-titre',
        MontageLayer.title => 'Titre',
        MontageLayer.wish => 'Texte',
        MontageLayer.chip => 'Badge',
        MontageLayer.brand => 'Logo Afrolook',
        MontageLayer.pseudo => '@pseudo',
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
    required this.sound,
    this.texts = const [],
    this.country = false,
    this.defaultCountry = 'TG',
    this.indep = false,
    this.dualSample,
    this.baby = false,
  });

  bool get usesPrenom => texts.any((t) => t.contains('{prenom}'));
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
final int _nextYear = DateTime.now().year + 1;

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
];

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
