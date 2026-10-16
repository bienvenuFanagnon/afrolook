import 'dart:convert';

import 'package:flutter/services.dart';

import '../../cards/card_flags.dart';
import '../../cards/card_models.dart' show compactCount;
import 'montage_catalog.dart';
import 'montage_music.dart';

/// Tout ce que la personne a choisi ou modifié sur un template. Ce qui reste à null garde le contenu pré-rempli.
class MontageState {
  MontageState(this.template)
      : country = template.defaultCountry,
        useVideo = template.sampleIsVideo,
        animated = template.fx != MontageFx.none,
        music = studioTrack(template.music) == null ? null : MontageMusic.free(studioTrack(template.music)!);

  final MontageTemplate template;

  /// Photo ou vidéo de la personne (null = média d'exemple du template).
  String? photoPath;
  String? videoPath;
  bool useVideo;
  String? secondPhotoPath;

  bool post = false;
  bool animated;
  String prenom = 'Kofi';
  String country;

  /// Pays sans date connue : type de fête choisi (true = indépendance) et date saisie.
  bool indepChosen = false;
  String customDate = '';

  int textIndex = 0;
  String? kick;
  String? title;
  String? wish;
  final Set<MontageLayer> hidden = {};

  /// Musique (null = sans musique). Avec une musique, le montage est toujours une vidéo.
  MontageMusic? music;
  int musicStartMs = 0;

  /// Durée de la vidéo quand la base est une photo et qu'il y a une musique (secondes).
  int musicSeconds = 15;

  /// Vidéo de la personne : garder son propre son sous la musique.
  bool keepVideoAudio = false;

  /// Chiffres affichés (null = exemple du template pour les j'aime/commentaires, vrai nombre d'abonnés).
  String? likesText;
  String? commentsText;
  String? followersText;

  String likesLabel() => montageCount(likesText) ?? compactCount(template.sampleStats.$1);
  String commentsLabel() => montageCount(commentsText) ?? compactCount(template.sampleStats.$2);
  String? followersLabel(int real) => montageCount(followersText) ?? (real > 0 ? compactCount(real) : null);

  bool shows(MontageLayer l) => !hidden.contains(l);

  bool get hasVideo => useVideo;
  bool get fxActive => template.fx != MontageFx.none && shows(MontageLayer.fx);

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
