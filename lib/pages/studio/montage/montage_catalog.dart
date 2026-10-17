// Catalogue des templates « prêts à poster » du Studio : chaque template arrive déjà rempli
// (photo d'exemple, sur-titre, titre, texte de souhait, badge, effet) ; la personne remplace ce qu'elle veut.

import 'package:flutter/material.dart';

enum MontageCat { situations, emotions, insta, music, culture, fetes }

extension MontageCatX on MontageCat {
  String get label => switch (this) {
        MontageCat.situations => '😂 Situations',
        MontageCat.emotions => '💫 Émotions',
        MontageCat.insta => '📸 Insta',
        MontageCat.music => '🎵 Musique',
        MontageCat.culture => '🌍 Culture',
        MontageCat.fetes => '🎊 Fêtes',
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
  });

  bool get usesPrenom => texts.any((t) => t.contains('{prenom}'));

  /// Musique gratuite proposée d'office (modifiable ou retirable dans l'éditeur).
  String? get music => kTemplateMusic[id];

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
final int _nextYear = DateTime.now().year + 1;

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
];

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
  'indep': 'fanfare', 'nouvelan': 'fanfare', 'ramadan': 'oud', 'noel': 'noel', 'valentin': 'love_afro', 'anniv': 'highlife',
  'diplome': 'fanfare', 'nouveaujob': 'afrobeat',
  'chanson': 'afrobeat', 'dedicace': 'love_afro', 'soiree': 'amapiano', 'chill': 'nuit', 'louange': 'kora_calme', 'freestyle': 'afro_trap',
  'danse': 'coupe_decale', 'slow': 'love_afro', 'concert': 'afrobeat', 'oldschool': 'highlife', 'studio': 'afro_trap', 'sortie': 'afrobeat', 'focus': 'zen_kalimba',
  'paques': 'noel', 'meres': 'love_afro', 'peres': 'highlife', 'femmes': 'amapiano', 'afrique': 'highlife', 'tabaski': 'oud', 'travail': 'workout',
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
