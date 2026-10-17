import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/tr.dart';
import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../services/template_link.dart';
import '../../widgets/studio/post_template_try.dart';
import 'card_entry.dart';
import 'card_flags.dart';
import 'card_models.dart';

/// Une fête du jour : de quoi inviter la personne à créer une carte aux couleurs de l'occasion.
class CardEvent {
  const CardEvent({
    required this.id,
    required this.emoji,
    required this.title,
    required this.body,
    required this.text,
    required this.style,
    required this.colors,
    this.country,
    this.flagFree = false,
  });

  /// Identifiant unique de cette fête cette année (sert à n'afficher l'invitation qu'une fois).
  final String id;
  final String emoji;
  final String title;
  final String body;

  /// Texte proposé pour la carte.
  final String text;
  final CardStyleId style;
  final List<Color> colors;

  /// Fête nationale : le pays (code ISO) dont on montre le drapeau.
  final String? country;

  /// Les styles « drapeau » sont offerts toute la journée.
  final bool flagFree;
}

/// Une fête qui arrive (ou qui est là) : [daysLeft] jours avant la date officielle, 0 = aujourd'hui.
class CardEventSoon {
  const CardEventSoon(this.event, this.daysLeft);
  final CardEvent event;
  final int daysLeft;

  /// Type de fête : national, africaday, fitr, adha, newyear, noel, valentin, femmes, travail, paques, meres, peres.
  String get kind => event.id.split('-').first;

  /// Template du Studio qui correspond à cette fête (id du catalogue du Studio).
  String? get studioTemplateId => _studioTemplates[kind];

  static const Map<String, String> _studioTemplates = {
    'national': 'indep', 'africaday': 'afrique', 'fitr': 'ramadan', 'adha': 'tabaski', 'newyear': 'nouvelan', 'noel': 'noel',
    'valentin': 'valentin', 'femmes': 'femmes', 'travail': 'travail', 'paques': 'paques', 'meres': 'meres', 'peres': 'peres',
  };

  /// Nom court de la fête, pour « Noël dans 3 jours ».
  String get name => switch (kind) {
        'national' => tr('Fête nationale · {pays}', {'pays': CardFlags.name(event.country ?? '')}),
        'africaday' => tr('Journée de l\'Afrique'),
        'fitr' => tr('Aïd el-Fitr'),
        'adha' => tr('Tabaski'),
        'newyear' => tr('Nouvel An'),
        'noel' => tr('Noël'),
        'valentin' => tr('Saint-Valentin'),
        'femmes' => tr('Journée de la femme'),
        'travail' => tr('Fête du travail'),
        'paques' => tr('Pâques'),
        'meres' => tr('Fête des mères'),
        'peres' => tr('Fête des pères'),
        _ => event.title,
      };

  /// « Noël dans 3 jours », « Noël demain », ou le titre de la fête le jour J.
  String get headline => daysLeft <= 0
      ? event.title
      : daysLeft == 1
          ? tr('{fete} demain', {'fete': name})
          : tr('{fete} dans {n} jours', {'fete': name, 'n': daysLeft});
}

/// Fêtes nationales, fêtes de l'Afrique et fêtes internationales : calcul de la fête du jour et invitation dans l'application.
class CardEvents {
  CardEvents._();

  /// Fêtes nationales [mois, jour] (même table que le serveur : `NATIONAL_DAYS` de `functions/src/cards/cards.ts`).
  /// L'Afrique d'abord ; un pays absent n'a simplement pas d'invitation.
  static const Map<String, (int, int)> nationalDays = {
    'DZ': (7, 5), 'AO': (11, 11), 'BJ': (8, 1), 'BW': (9, 30), 'BF': (12, 11), 'BI': (7, 1), 'CV': (7, 5), 'CM': (5, 20), 'CF': (12, 1), 'TD': (8, 11),
    'KM': (7, 6), 'CG': (8, 15), 'CD': (6, 30), 'CI': (8, 7), 'DJ': (6, 27), 'EG': (7, 23), 'GQ': (10, 12), 'ER': (5, 24), 'SZ': (9, 6), 'GA': (8, 17),
    'GM': (2, 18), 'GH': (3, 6), 'GN': (10, 2), 'GW': (9, 24), 'KE': (12, 12), 'LS': (10, 4), 'LR': (7, 26), 'LY': (12, 24), 'MG': (6, 26), 'MW': (7, 6),
    'ML': (9, 22), 'MR': (11, 28), 'MU': (3, 12), 'MA': (7, 30), 'MZ': (6, 25), 'NA': (3, 21), 'NE': (8, 3), 'NG': (10, 1), 'RW': (7, 1), 'ST': (7, 12),
    'SN': (4, 4), 'SC': (6, 29), 'SL': (4, 27), 'SO': (7, 1), 'ZA': (4, 27), 'SS': (7, 9), 'TZ': (12, 9), 'TG': (4, 27), 'TN': (3, 20), 'UG': (10, 9),
    'ZM': (10, 24), 'ZW': (4, 18),
    'FR': (7, 14), 'BE': (7, 21), 'CA': (7, 1), 'US': (7, 4), 'BR': (9, 7), 'DE': (10, 3), 'IT': (6, 2), 'CH': (8, 1), 'HT': (1, 1), 'JM': (8, 6),
  };

  /// Aïd el-Fitr et Aïd el-Adha (Tabaski) : dates approximatives du calendrier lunaire (±1 jour selon l'observation de la lune),
  /// affichées ce jour-là et le lendemain.
  static final Map<int, List<DateTime>> _eidFitr = {
    2026: [DateTime(2026, 3, 20)],
    2027: [DateTime(2027, 3, 10)],
    2028: [DateTime(2028, 2, 27)],
    2029: [DateTime(2029, 2, 15)],
    2030: [DateTime(2030, 2, 5)],
  };
  static final Map<int, List<DateTime>> _eidAdha = {
    2026: [DateTime(2026, 5, 27)],
    2027: [DateTime(2027, 5, 17)],
    2028: [DateTime(2028, 5, 5)],
    2029: [DateTime(2029, 4, 24)],
    2030: [DateTime(2030, 4, 14)],
  };

  /// La date de Pâques (calendrier grégorien, algorithme de Meeus/Jones/Butcher).
  static DateTime easter(int y) {
    final a = y % 19, b = y ~/ 100, c = y % 100, d = b ~/ 4, e = b % 4;
    final f = (b + 8) ~/ 25, g = (b - f + 1) ~/ 3;
    final h = (19 * a + b - d - g + 15) % 30;
    final i = c ~/ 4, k = c % 4;
    final l = (32 + 2 * e + 2 * i - h - k) % 7;
    final m = (a + 11 * h + 22 * l) ~/ 451;
    final month = (h + l - 7 * m + 114) ~/ 31;
    final day = (h + l - 7 * m + 114) % 31 + 1;
    return DateTime(y, month, day);
  }

  /// Le n-ième [weekday] (1 = lundi … 7 = dimanche) d'un mois.
  static DateTime nthWeekday(int y, int month, int weekday, int n) {
    final first = DateTime(y, month, 1);
    final shift = (weekday - first.weekday) % 7;
    return DateTime(y, month, 1 + shift + 7 * (n - 1));
  }

  static bool _same(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  /// Pays dont c'est la fête nationale aujourd'hui, pour une personne de ce pays (code ISO), sinon null.
  static String? nationalDayCountry(String? country, DateTime now) {
    final c = (country ?? '').toUpperCase();
    final d = nationalDays[c];
    return d != null && d.$1 == now.month && d.$2 == now.day ? c : null;
  }

  static String _slug(String s) {
    const from = 'àâäéèêëîïôöùûüçñ';
    const to = 'aaaeeeeiioouuucn';
    var out = s.toLowerCase();
    for (var i = 0; i < from.length; i++) {
      out = out.replaceAll(from[i], to[i]);
    }
    return out.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  /// Un style « drapeau » différent chaque jour de la fête (pour que les cartes ne se ressemblent pas toutes).
  static CardStyleId _flagStyle(DateTime now) {
    const list = [CardStyleId.flag, CardStyleId.pride, CardStyleId.passport, CardStyleId.supporter, CardStyleId.stamp, CardStyleId.duo];
    return list[(now.year + now.month + now.day) % list.length];
  }

  /// La fête du jour pour cette personne : la fête nationale de son pays d'abord, puis les fêtes de l'Afrique et religieuses,
  /// puis les fêtes internationales. Null s'il n'y en a pas.
  static CardEvent? forToday(String? country, DateTime now) {
    final y = now.year;
    final nat = nationalDayCountry(country, now);
    if (nat != null) {
      final name = CardFlags.name(nat);
      return CardEvent(
        id: 'national-$nat-$y',
        emoji: '🎉',
        title: tr('C\'est la fête nationale : {pays} !', {'pays': name}),
        body: tr('Montre ta fierté : crée une carte aux couleurs de ton pays et publie-la. Aujourd\'hui, tous les styles drapeau sont offerts.'),
        text: '${tr('Joyeuse fête nationale')}, $name ! #fetenationale #${_slug(name)}',
        style: _flagStyle(now),
        colors: const [Color(0xFF0F5132), Color(0xFF1FAA59)],
        country: nat,
        flagFree: true,
      );
    }
    CardEvent ev(String id, String emoji, String title, String body, String text, CardStyleId style, List<Color> colors) =>
        CardEvent(id: '$id-$y', emoji: emoji, title: title, body: body, text: text, style: style, colors: colors, country: country == null ? null : CardFlags.normalize(country, or: ''));

    if (now.month == 5 && now.day == 25) {
      return ev('africaday', '🌍', tr('Journée de l\'Afrique'), tr('Célèbre le continent : une carte à partager avec ta communauté.'), '${tr('Bonne Journée de l\'Afrique')} ! 🌍 #journeedelafrique', CardStyleId.pride, const [Color(0xFF7A2E0E), Color(0xFFF2B705)]);
    }
    for (final d in _eidFitr[y] ?? const <DateTime>[]) {
      if (_same(now, d) || _same(now, d.add(const Duration(days: 1)))) {
        return ev('fitr', '🌙', tr('Aïd el-Fitr'), tr('Souhaite une belle fête à tes proches avec une carte.'), '${tr('Aïd Moubarak')} ! 🌙 #aid', CardStyleId.tarot, const [Color(0xFF1A0B2E), Color(0xFF4B1D6B)]);
      }
    }
    for (final d in _eidAdha[y] ?? const <DateTime>[]) {
      if (_same(now, d) || _same(now, d.add(const Duration(days: 1)))) {
        return ev('adha', '🐑', tr('Tabaski (Aïd el-Kébir)'), tr('Souhaite une belle fête à tes proches avec une carte.'), '${tr('Bonne fête de la Tabaski')} ! #tabaski', CardStyleId.tarot, const [Color(0xFF1A0B2E), Color(0xFF4B1D6B)]);
      }
    }
    if ((now.month == 12 && now.day == 31) || (now.month == 1 && now.day == 1)) {
      final year = now.month == 12 ? y + 1 : y;
      return CardEvent(
        id: 'newyear-$year',
        emoji: '🎆',
        title: tr('Bonne année {n} !', {'n': year}),
        body: tr('Crée ta carte de vœux et partage-la avec tes proches.'),
        text: '${tr('Bonne année')} $year ! 🎆 #bonneannee',
        style: CardStyleId.neon,
        colors: const [Color(0xFF0B0420), Color(0xFF7C3AED)],
        country: country == null ? null : CardFlags.normalize(country, or: ''),
      );
    }
    if (now.month == 12 && (now.day == 24 || now.day == 25)) {
      return ev('noel', '🎄', tr('Joyeux Noël !'), tr('Crée ta carte de Noël et partage-la avec tes proches.'), '${tr('Joyeux Noël à vous et à vos proches')} ! 🎄 #noel', CardStyleId.glass, const [Color(0xFF7A0F1A), Color(0xFF14532D)]);
    }
    if (now.month == 2 && now.day == 14) {
      return ev('valentin', '❤️', tr('Saint-Valentin'), tr('Un mot doux, une jolie carte : dis-le avec style.'), '${tr('Joyeuse Saint-Valentin')} ! ❤️ #saintvalentin', CardStyleId.quote, const [Color(0xFFB0306E), Color(0xFFFF6FA3)]);
    }
    if (now.month == 3 && now.day == 8) {
      return ev('femmes', '💐', tr('Journée des droits des femmes'), tr('Rends hommage aux femmes de ta vie avec une carte.'), '${tr('Bonne Journée internationale des droits des femmes')} ! 💐 #8mars', CardStyleId.magazine, const [Color(0xFF6D1B7B), Color(0xFFE91E63)]);
    }
    if (now.month == 5 && now.day == 1) {
      return ev('travail', '🛠️', tr('Fête du travail'), tr('Une carte pour celles et ceux qui font avancer le pays.'), '${tr('Bonne fête du travail')} ! #fetedutravail', CardStyleId.sport, const [Color(0xFF0A1F44), Color(0xFF1B6BFF)]);
    }
    if (_same(now, easter(y))) {
      return ev('paques', '🐣', tr('Pâques'), tr('Souhaite de joyeuses Pâques avec une carte.'), '${tr('Joyeuses Pâques')} ! 🐣 #paques', CardStyleId.glass, const [Color(0xFFFFB86B), Color(0xFF7C5CFF)]);
    }
    if (_same(now, nthWeekday(y, 5, DateTime.sunday, 2))) {
      return ev('meres', '💐', tr('Fête des mères'), tr('Dis merci à maman avec une jolie carte.'), '${tr('Bonne fête à toutes les mamans')} ! 💐 #fetedesmeres', CardStyleId.quote, const [Color(0xFFB0306E), Color(0xFFFFB86B)]);
    }
    if (_same(now, nthWeekday(y, 6, DateTime.sunday, 3))) {
      return ev('peres', '👔', tr('Fête des pères'), tr('Dis merci à papa avec une carte.'), '${tr('Bonne fête à tous les papas')} ! #fetedespapas', CardStyleId.sport, const [Color(0xFF0A1F44), Color(0xFFFF5A1F)]);
    }
    return null;
  }

  /// Fêtes dont la date officielle tombe dans les [maxDays] prochains jours (aujourd'hui compris) : la plus proche d'abord.
  /// Noël (25 décembre) et le Nouvel An (1er janvier) sont comptés jusqu'à leur date officielle, pas jusqu'à la veille.
  static CardEventSoon? upcoming(String? country, DateTime now, {int maxDays = 3}) {
    final today = DateTime(now.year, now.month, now.day);
    for (var d = 0; d <= maxDays + 1; d++) {
      final day = DateTime(today.year, today.month, today.day + d);
      final ev = forToday(country, day);
      if (ev == null) continue;
      final kind = ev.id.split('-').first;
      final official = switch (kind) {
        'noel' => DateTime(day.year, 12, 25),
        'newyear' => DateTime(day.month == 12 ? day.year + 1 : day.year, 1, 1),
        _ => day,
      };
      var left = DateTime.utc(official.year, official.month, official.day).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
      if (left < 0) left = 0; // Aïd : le lendemain de la date officielle
      return left > maxDays ? null : CardEventSoon(ev, left);
    }
    return null;
  }

  static String _key(String id) => 'card_event_seen_$id';

  /// À appeler depuis l'accueil : si une fête arrive (dans 3 jours ou moins) ou est là, et que l'invitation n'a pas encore été vue,
  /// l'affiche : une fois quand la fête approche, une fois le jour J. Elle propose le template du Studio ou une carte.
  static Future<void> maybeShow(BuildContext context, {DateTime? now}) async {
    if (kIsWeb) return;
    final me = context.read<UserAuthProvider>().loginUserData;
    final soon = upcoming(me.countryData?['countryCode'], now ?? DateTime.now());
    if (soon == null) return;
    final ev = soon.event;
    try {
      final sp = await SharedPreferences.getInstance();
      // « jour J » garde l'ancienne clé : personne ne revoit l'invitation d'une fête déjà vue
      final key = soon.daysLeft == 0 ? _key(ev.id) : '${_key(ev.id)}_soon';
      if (sp.getBool(key) == true) return;
      await sp.setBool(key, true);
    } catch (_) {}
    if (!context.mounted) return;
    final template = soon.studioTemplateId;
    final choice = await showDialog<String>(context: context, barrierDismissible: true, builder: (_) => CardEventDialog(event: ev, daysLeft: soon.daysLeft, headline: soon.headline, templateId: template));
    if (!context.mounted) return;
    if (choice == 'card') {
      await CardEntry.openCompose(context, text: ev.text, style: ev.style, country: ev.country);
    } else if (choice == 'template' && template != null) {
      await TemplateTry.open(context, TemplateRef.montage(template));
    }
  }
}

/// L'invitation : le drapeau (ou un emoji) en grand, ce qui se passe aujourd'hui et un bouton pour créer la carte.
class CardEventDialog extends StatelessWidget {
  const CardEventDialog({super.key, required this.event, this.daysLeft = 0, this.headline, this.templateId});
  final CardEvent event;

  /// Jours avant la fête (0 = aujourd'hui) ; [headline] : « Noël dans 3 jours » ; [templateId] : le template du Studio à proposer.
  final int daysLeft;
  final String? headline;
  final String? templateId;

  @override
  Widget build(BuildContext context) {
    final e = event;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          color: const Color(0xFF111111),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              height: 150,
              child: Stack(fit: StackFit.expand, children: [
                if (e.flagFree && e.country != null)
                  CardFlag(e.country!)
                else
                  DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: e.colors))),
                const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x22000000), Color(0xAA000000)]))),
                Center(child: Text(e.emoji, style: const TextStyle(fontSize: 64))),
                Positioned(
                  right: 8,
                  top: 8,
                  child: IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white), onPressed: () => Navigator.pop(context, false)),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
              child: Column(children: [
                Text(headline ?? e.title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800, height: 1.2)),
                const SizedBox(height: 10),
                Text(daysLeft > 0 ? tr('Prépare ton post à l\'avance avec un template tout prêt, ou crée une carte, et publie-le le jour J.') : e.body, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFBDBDBD), fontSize: 14.5, height: 1.4)),
                if (e.flagFree && daysLeft == 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0xFFFFE14D), borderRadius: BorderRadius.circular(20)),
                    child: Text(tr('Styles drapeau offerts aujourd\'hui'), style: const TextStyle(color: Color(0xFF1F1F1F), fontSize: 12.5, fontWeight: FontWeight.w800)),
                  ),
                ],
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 18),
              child: Column(children: [
                if (templateId != null) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), backgroundColor: const Color(0xFF2ECC71), foregroundColor: const Color(0xFF0E0E0E), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28))),
                      onPressed: () => Navigator.pop(context, 'template'),
                      icon: const Icon(Icons.movie_filter_rounded),
                      label: Text(tr('Créer un post avec le template'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13), foregroundColor: Colors.white, side: const BorderSide(color: Color(0xFF3A3A3A)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28))),
                      onPressed: () => Navigator.pop(context, 'card'),
                      icon: const Icon(Icons.auto_awesome_rounded),
                      label: Text(tr('Créer ma carte'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                    ),
                  ),
                ] else
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), backgroundColor: const Color(0xFF2ECC71), foregroundColor: const Color(0xFF0E0E0E), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28))),
                      onPressed: () => Navigator.pop(context, 'card'),
                      icon: const Icon(Icons.auto_awesome_rounded),
                      label: Text(tr('Créer ma carte'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    ),
                  ),
                TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Plus tard'), style: const TextStyle(color: Color(0xFF9E9E9E)))),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
