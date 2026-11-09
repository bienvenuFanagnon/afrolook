import 'dart:convert';
import 'dart:ui' show Offset;

import 'package:flutter/services.dart';

import '../../cards/card_flags.dart';
import '../../cards/card_models.dart' show compactCount;
import 'montage_catalog.dart';
import 'montage_look.dart';
import 'montage_music.dart';
import 'montage_pin.dart';
import 'montage_stickers.dart';

/// Noms des effets animés proposés à la personne (sans modèle).
const Map<MontageFx, String> kMontageFxLabels = {
  MontageFx.money: '💸 Billets',
  MontageFx.hearts: '❤️ Cœurs',
  MontageFx.coins: '🪙 Pièces',
  MontageFx.rain: '🌧️ Pluie',
  MontageFx.storm: '⛈️ Orage',
  MontageFx.cloud: '☁️ Nuages',
  MontageFx.sparkle: '✨ Étincelles',
  MontageFx.fire: '🔥 Feu',
  MontageFx.rays: '🌟 Rayons',
  MontageFx.speed: '💨 Vitesse',
  MontageFx.bokeh: '🔆 Lumières',
  MontageFx.zzz: '😴 Zzz',
  MontageFx.leaves: '🍃 Feuilles',
  MontageFx.crown: '👑 Couronnes',
  MontageFx.waves: '🌊 Vagues',
  MontageFx.disco: '🪩 Disco',
  MontageFx.sunset: '🌅 Coucher de soleil',
  MontageFx.fireworks: '🎆 Feux d\'artifice',
  MontageFx.moon: '🌙 Lune',
  MontageFx.snow: '❄️ Neige',
  MontageFx.confetti: '🎉 Confettis',
  MontageFx.ring: '💍 Alliances',
  MontageFx.baby: '👶 Bébé',
};

/// Modèles d'affiche dont le titre reste affiché d'office (événements, invitations, annonces).
const Set<String> kTemplateShownTitle = {'evenement', 'anniv_minuteur', 'fa_change', 'vie_mariage', 'vie_bebe', 'vie_voyage', 'fe_sylvestre', 'we_match', 'we_samedi'};

/// Tout ce que la personne a choisi ou modifié sur un template. Ce qui reste à null garde le contenu pré-rempli.
class MontageState {
  MontageState(this.template)
      : country = template.defaultCountry,
        useVideo = template.sampleIsVideo,
        keepVideoAudio = studioTrack(template.music) == null,   // sans musique, ta voix est gardée ; avec la musique d'un modèle, seule la musique joue (comme avant)
        animated = false,   // jamais d'effet animé par défaut : le rendu reste sobre et professionnel ; la personne l'active elle-même
        music = studioTrack(template.music) == null ? null : MontageMusic.free(studioTrack(template.music)!);

  final MontageTemplate template;

  /// Photo ou vidéo de la personne (null = média d'exemple du template).
  String? photoPath;
  String? videoPath;
  bool useVideo;
  String? secondPhotoPath;

  bool post = false;

  /// Format paysage 16:9 (vidéo filmée ou choisie en paysage : elle garde sa forme). Sinon [post] = 4:5, et par défaut 9:16.
  bool landscape = false;

  /// `story` (9:16), `post` (4:5) ou `landscape` (16:9) : ce que le serveur fabrique.
  String get format => landscape ? 'landscape' : (post ? 'post' : 'story');

  double get aspect => landscape ? 16 / 9 : (post ? 4 / 5 : 9 / 16);

  /// Taille du film fabriqué par le serveur (largeur, hauteur), aussi celle des calques de la fin Afrolook.
  (int, int) get filmSize => landscape ? (1280, 720) : (post ? (720, 900) : (720, 1280));

  void setFormat(String f) {
    landscape = f == 'landscape';
    post = f == 'post';
  }

  bool animated;
  String prenom = 'Kofi';
  String country;

  /// Pays sans date connue : type de fête choisi (true = indépendance) et date saisie.
  bool indepChosen = false;
  String customDate = '';

  int textIndex = 0;

  /// Export seulement : n'afficher que cet autocollant (calque d'un message temporisé), ou tous sauf les temporisés (calque principal).
  String? exportOnlySticker;
  bool exportExcludeTimed = false;

  /// Capture des calques pour l'export en cours : les aperçus en direct des 2e médias (vidéo, image) n'y entrent JAMAIS (le serveur pose les vraies vidéos ; sinon l'aperçu opaque
  /// serait collé par-dessus tout le film et le figerait).
  bool exportCapture = false;
  String? kick;
  String? title;
  String? wish;
  /// Calques masqués. Un modèle s'ouvre PROPRE (demande du 09/11/2026) : ni sur-titre, ni titre, ni texte, ni badge, ni logo, ni abonnés, ni effet animé ; la personne place elle-même ce qu'elle veut
  /// (réglages « Calques »). Exceptions : un modèle dont le texte EST le contenu (pensées, ambiances, drôles) garde cet unique texte, et un modèle sur trois montre les j'aime et commentaires.
  late final Set<MontageLayer> hidden = defaultHidden(template);

  static Set<MontageLayer> defaultHidden(MontageTemplate t) {
    if (t.id == kPlainTemplateId || t.musicOverridden) return {MontageLayer.fx};   // média seul, ou modèle d'une personne : ce que son créateur a écrit reste affiché
    final h = <MontageLayer>{MontageLayer.fx, MontageLayer.kick, MontageLayer.title, MontageLayer.wish, MontageLayer.chip, MontageLayer.brand, MontageLayer.followers};
    if (t.cat == MontageCat.pensees) h.remove(MontageLayer.wish);
    if (t.cat == MontageCat.ambiances || t.cat == MontageCat.droles) h.remove(MontageLayer.title);
    // une affiche d'événement ou d'invitation n'a pas de sens sans son titre (« Soirée de lancement », « Le grand jour ») ; le duo réaction garde son sous-titre et son compteur
    if (t.cat == MontageCat.evenements || kTemplateShownTitle.contains(t.id)) h.remove(MontageLayer.title);
    if (t.id == 'duo_reaction') h.removeAll({MontageLayer.title, MontageLayer.wish, MontageLayer.stats});
    var hash = 0;
    for (final c in t.id.codeUnits) {
      hash = (hash * 31 + c) & 0x7fffffff;
    }
    if (hash % 3 != 0 && t.id != 'duo_reaction') h.add(MontageLayer.stats);   // un modèle sur trois garde les j'aime et commentaires
    return h;
  }

  /// Calques masqués d'un montage « sans habillage » : tout, sauf (si [signature]) la signature de la personne (@pseudo, ou #titre pour un canal).
  static Set<MontageLayer> plainHidden({bool signature = false}) => {for (final l in MontageLayer.values) if (!(signature && l == MontageLayer.pseudo)) l};

  /// Éléments que la personne a DÉPLACÉS (`pseudo`, `stats`, `text`, `brand`, `block`) : identifiant → centre dans le cadre (fraction 0 à 1). Absent = emplacement du modèle.
  /// L'affichage ramène toujours l'élément à l'intérieur du cadre : il ne se perd jamais.
  final Map<String, Offset> moved = {};

  /// Autocollants (emojis, pastilles, logo) ajoutés par la personne, du plus ancien au plus récent (le dernier est au-dessus).
  final List<MontageSticker> stickers = [];

  /// Médias épinglés (extraits d'autres vidéos, images de la galerie), au plus [kMaxPins], posés par le serveur ; seulement un aperçu dans l'éditeur.
  /// Le 1er peut tenir une disposition ([layout]) ; les suivants sont des images posées librement.
  final List<MontagePin> pins = [];

  bool get canAddPin => pins.length < kMaxPins;

  /// Retire UN média épinglé et son crédit « avec @nom ». Si c'était le 1er (celui des dispositions) ou le dernier, les dispositions s'arrêtent : les images restantes sont libres.
  void removePin(MontagePin p) {
    final wasFirst = pins.isNotEmpty && identical(pins.first, p);
    stickers.removeWhere((e) => e.id == 'credit_${p.id}');
    pins.remove(p);
    if (pins.isEmpty || wasFirst) layout = null;
  }

  /// Retire TOUS les médias épinglés (et leurs crédits).
  void clearPins() {
    for (final p in pins) {
      stickers.removeWhere((e) => e.id == 'credit_${p.id}');
    }
    pins.clear();
    layout = null;
  }

  /// Montage à DEUX vidéos (réponse en vidéo) : `tb` haut/bas, `sbs` côte à côte, `bar` bandeau en haut ; null = vidéo épinglée dans un coin.
  String? layout;

  /// Inverse les places (ta vidéo en premier).
  bool layoutSwap = false;

  /// Part de la PREMIÈRE place (haut ou gauche), 25 % à 75 % ; null = la moitié (bandeau : son format 16:9).
  double? layoutRatio;

  /// Zoom (1 à 2,5) de la vidéo ajoutée et de la tienne dans leur place : la vidéo remplit la place puis est recadrée au centre.
  double originZoom = 1;
  double meZoom = 1;

  /// Garder le son de la vidéo d'origine, et son volume (0 à 1,5).
  bool originAudio = true;
  double originVolume = 1.0;

  /// La vidéo ajoutée reboucle tant que ta vidéo dure (sinon elle reste figée sur sa dernière image).
  bool originLoop = true;

  /// Les deux places en fractions du cadre (même découpage que le serveur) : (vidéo d'origine, ta vidéo). Null si aucune disposition.
  /// Part de la première place (haut ou gauche) : celle réglée, sinon la moitié (le bandeau garde son format 16:9).
  double get firstShare => (layoutRatio ?? (layout == 'bar' ? ((9 / 16) * aspect).clamp(0.0, .4).toDouble() : .5)).clamp(.25, .75).toDouble();

  ({Rect origin, Rect me})? get layoutFracs => layout == null ? null : montageLayoutFracs(layout!, layoutSwap, aspect, ratio: layoutRatio);

  /// Texte libre posé sur la photo ou la vidéo (outil « Texte » de l'éditeur) : vide = aucun. Fonctionne avec tous les modèles, y compris « sans habillage ».
  String freeText = '';

  /// Couleur du texte libre (indice dans [kFreeTextColors]) et position verticale (0 haut, 1 milieu, 2 bas).
  int freeColor = 0;
  int freePos = 1;

  /// Style d'écriture (indice dans [kFreeTextFonts]), arrière-plan (0 aucun, 1 plein, 2 transparent, 3 contour) et sa couleur (indice dans [kFreeTextColors]), cadre (0 à 4).
  int freeFont = 0;
  int freeBg = 0;
  int freeBgColor = 2;
  int freeFrame = 0;

  /// Looks de couleur choisis, CUMULABLES (3 au plus) ; vide = l'ambiance propre au modèle. Saturations multipliées, luminosités additionnées (calcul exact : la matrice
  /// de saturation garde le gris), teintes superposées dans l'ordre. Le serveur applique la MÊME matrice que l'aperçu du téléphone.
  final List<MontageLook> looks = [];

  /// Nombre de looks cumulables au plus.
  static const int maxLooks = 3;

  /// Le dernier look choisi (null = aucun) ; l'affecter remplace tous les looks par celui-là (ou les vide avec null).
  MontageLook? get look => looks.isEmpty ? null : looks.last;
  set look(MontageLook? l) {
    looks.clear();
    if (l != null) looks.add(l);
  }

  /// Ajoute le look s'il n'y est pas, le retire sinon. Renvoie false si la limite est atteinte (rien n'est changé).
  bool toggleLook(MontageLook l) {
    final i = looks.indexWhere((e) => e.id == l.id);
    if (i >= 0) {
      looks.removeAt(i);
      return true;
    }
    if (looks.length >= maxLooks) return false;
    looks.add(l);
    return true;
  }

  double get saturation => looks.isEmpty ? template.saturation : looks.fold<double>(1, (a, l) => a * l.saturation);
  double get brightness => looks.isEmpty ? template.brightness : looks.fold<double>(0, (a, l) => a + l.brightness);

  /// Effet animé choisi par la personne : null = celui du modèle, [MontageFx.none] = aucun. Utilisable SANS modèle (montage « sans habillage »).
  MontageFx? fxChoice;

  /// L'effet animé en vigueur : le choix de la personne, sinon celui du modèle.
  MontageFx get fx => fxChoice ?? template.fx;

  /// Musique (null = sans musique). Avec une musique, le montage est toujours une vidéo.
  MontageMusic? music;
  int musicStartMs = 0;

  /// Durée de la vidéo quand la base est une photo et qu'il y a une musique (secondes).
  int musicSeconds = 15;

  /// Son de la vidéo de la personne (interrupteur « Son de ma vidéo ») : gardé ou coupé ; son volume est [videoVolume].
  bool keepVideoAudio;

  /// Mixage : volume du son choisi (0 à 1), volume de la voix de la vidéo (0 à 1,5) et baisse automatique de la musique quand on parle.
  double musicVolume = 1;
  double videoVolume = .9;
  bool duckMusic = false;

  /// Fin animée Afrolook (2,8 s : logo, @pseudo, invitation) ajoutée à la fin d'une vidéo exportée. Par défaut oui ; seul un compte Gold peut la retirer.
  bool outro = true;

  /// Chiffres affichés (null = exemple du template pour les j'aime/commentaires, vrai nombre d'abonnés).
  String? likesText;
  String? commentsText;
  String? followersText;

  String likesLabel() => montageCount(likesText) ?? compactCount(template.sampleStats.$1);
  String commentsLabel() => montageCount(commentsText) ?? compactCount(template.sampleStats.$2);
  String? followersLabel(int real) => montageCount(followersText) ?? (real > 0 ? compactCount(real) : null);

  bool shows(MontageLayer l) => !hidden.contains(l);

  bool get hasVideo => useVideo;
  bool get fxActive => fxChoice != null ? fxChoice != MontageFx.none : (template.fx != MontageFx.none && shows(MontageLayer.fx));

  /// Le résultat sera une vidéo (vidéo de base, ou effet animé gardé) ; sinon une image fixe.
  bool get exportsVideo => hasVideo || (animated && fxActive) || music != null;
}

/// Chiffre écrit à la main : « 1400 » devient « 1,4k » ; un texte (« 12k », « 1,2 M ») reste tel quel ; vide = null.
String? montageCount(String? v) {
  final c = v?.trim();
  if (c == null || c.isEmpty) return null;
  final digits = c.replaceAll(RegExp(r'[\s\u00A0\u202F]'), '');
  if (RegExp(r'^\d{1,12}$').hasMatch(digits)) return compactCount(int.parse(digits));
  return c;
}

/// Textes du montage une fois le pays, le prénom et les choix appliqués.
class MontageTexts {
  MontageTexts(this.kick, this.title, this.wish, this.options);
  final String kick;
  final String title;
  final String wish;
  final List<String> options;
}

class MontageCountries {
  MontageCountries._();
  static Map<String, String>? _fr;

  /// Noms français de tous les pays (fichier du paquet country_code_picker, déjà dans l'app).
  static Future<Map<String, String>> load() async {
    if (_fr != null) return _fr!;
    try {
      final raw = await rootBundle.loadString('packages/country_code_picker/src/i18n/fr.json');
      final m = (jsonDecode(raw) as Map).map((k, v) => MapEntry(k.toString(), v.toString()));
      _fr = {for (final e in m.entries) if (CardFlags.flagExists(e.key)) e.key: e.value};
    } catch (_) {
      _fr = {for (final c in CardFlags.all()) c.code: c.name};
    }
    return _fr!;
  }

  static String name(String code) => _fr?[code] ?? CardFlags.name(code);

  /// Tous les pays : l'Afrique d'abord, puis le reste du monde, chacun par ordre alphabétique.
  static List<({String code, String name, bool africa})> sorted() {
    final m = _fr ?? {for (final c in CardFlags.all()) c.code: c.name};
    final list = [for (final e in m.entries) (code: e.key, name: e.value, africa: kAfricaCodes.contains(e.key))];
    list.sort((a, b) {
      if (a.africa != b.africa) return a.africa ? -1 : 1;
      return _plain(a.name).compareTo(_plain(b.name));
    });
    return list;
  }

  static String _plain(String s) {
    const from = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿÀÂÄÁÃÅÇÉÈÊËÍÌÎÏÑÓÒÔÖÕÚÙÛÜÝ';
    const to = 'aaaaaaceeeeiiiinooooouuuuyyAAAAAACEEEEIIIINOOOOOUUUUY';
    final b = StringBuffer();
    for (final r in s.runes) {
      final ch = String.fromCharCode(r);
      final i = from.indexOf(ch);
      b.write(i >= 0 ? to[i] : ch);
    }
    return b.toString().toLowerCase();
  }

  static bool matches(String name, String code, String query) {
    final q = _plain(query.trim());
    return q.isEmpty || _plain(name).contains(q) || code.toLowerCase() == q;
  }
}

MontageTexts resolveMontageTexts(MontageState s) {
  final t = s.template;
  final pays = MontageCountries.name(s.country);
  String fill(String x) => x.replaceAll('{prenom}', s.prenom.trim().isEmpty ? 'Kofi' : s.prenom.trim()).replaceAll('{pays}', pays);

  String kick = t.kick;
  String title = t.title;
  List<String> options = t.texts.map(fill).toList();

  if (t.indep) {
    final day = kNationalDays[s.country];
    final isIndep = day != null ? day.$4 : s.indepChosen;
    final date = day != null ? montageDayLabel(day.$1, day.$2) : s.customDate.trim();
    final ans = day?.$3 == null ? null : DateTime.now().year - day!.$3!;
    kick = date.isEmpty ? 'Choisis la date' : (day?.$3 != null ? '$date · ${day!.$3}' : date);
    title = isIndep ? 'Bonne fête de l’indépendance' : 'Bonne fête nationale';
    final quand = date.isEmpty ? 'Aujourd’hui' : date;
    options = [
      isIndep ? 'Joyeuse fête de l’indépendance, $pays !${ans != null ? ' $ans ans de liberté.' : ''} 🎉' : 'Bonne fête nationale, $pays ! 🎉',
      'Fier(e) de mes couleurs, fier(e) de mon histoire. Vive $pays ! 🎆',
      '$quand : on célèbre $pays ensemble ❤️',
    ];
  }
  final idx = s.textIndex.clamp(0, options.isEmpty ? 0 : options.length - 1);
  return MontageTexts(
    s.kick ?? fill(kick),
    s.title ?? fill(title),
    s.wish ?? (options.isEmpty ? '' : options[idx]),
    options,
  );
}

/// Espaces insécables avant « ! ? : ; » (typographie française) : la ponctuation ne part jamais seule à la ligne.
String frSpaces(String s) => s.replaceAllMapped(RegExp(r' ([!?:;»])'), (m) => ' ${m[1]}');


/// Les deux places d'une disposition, en fractions du cadre (largeur / hauteur = [aspect]) : (vidéo d'origine, ta vidéo). Null si la disposition est inconnue.
({Rect origin, Rect me})? montageLayoutFracs(String id, bool swap, double aspect, {double? ratio}) {
  final share = ratio?.clamp(0.25, 0.75).toDouble();
  Rect a, b;
  switch (id) {
    case 'tb':
      final h = share ?? .5;
      a = Rect.fromLTWH(0, 0, 1, h);
      b = Rect.fromLTWH(0, h, 1, 1 - h);
    case 'sbs':
      final w = share ?? .5;
      a = Rect.fromLTWH(0, 0, w, 1);
      b = Rect.fromLTWH(w, 0, 1 - w, 1);
    case 'bar':
      final h = share ?? ((9 / 16) * aspect).clamp(0.0, .4).toDouble();   // comme le serveur : min(L x 9/16, H x 0,4)
      a = Rect.fromLTWH(0, 0, 1, h);
      b = Rect.fromLTWH(0, h, 1, 1 - h);
    default:
      return null;
  }
  // les deux vidéos sont collées (aucun espace) ; `swap` met la vidéo ajoutée en second
  return swap ? (origin: b, me: a) : (origin: a, me: b);
}
