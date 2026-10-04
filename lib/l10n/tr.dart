import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'tr_canaux.dart';
import 'tr_menu.dart';
import 'tr_money.dart';
import 'tr_rewards.dart';
import 'tr_social.dart';
import 'tr_tuto.dart';

/// Traduction à partir du texte français (utilisée pour les écrans qui
/// avaient leurs textes écrits en dur).
///
///   Text(context.tr('Recharger'))
///   Text(context.tr('{n} pièces', {'n': TxAmount.fmt(coins)}))
///
/// Les dictionnaires sont rangés par zone (tr_menu.dart, tr_money.dart…),
/// avec pour chaque texte français ses traductions en, es, de, ar, pt, zh, sw.
/// Repli : langue demandée → anglais → texte français.
const List<Map<String, Map<String, String>>> _dictionaries = [kTrMenu, kTrMoney, kTrCanaux, kTrTuto, kTrSocial, kTrRewards];

final Map<String, Map<String, String>> _all = {
  for (final d in _dictionaries) ...d,
};

String trFor(String lang, String fr, [Map<String, Object?> args = const {}]) {
  var out = fr;
  if (lang != 'fr') {
    final entry = _all[fr];
    if (entry == null) {
      if (kDebugMode) debugPrint('🌐 tr manquant : "$fr"');
    } else {
      out = entry[lang] ?? entry['en'] ?? fr;
    }
  }
  args.forEach((k, v) => out = out.replaceAll('{$k}', '$v'));
  return out;
}

/// Langue courante de l'app, tenue à jour par LocaleProvider.
String trCurrentLanguage = 'fr';

/// Variante sans BuildContext (fonctions utilitaires, champs initialisés).
String tr(String fr, [Map<String, Object?> args = const {}]) => trFor(trCurrentLanguage, fr, args);

extension TrContext on BuildContext {
  String tr(String fr, [Map<String, Object?> args = const {}]) =>
      trFor(Localizations.localeOf(this).languageCode, fr, args);
}
