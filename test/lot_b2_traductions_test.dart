import 'dart:io';

import 'package:afrotok/l10n/tr.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tous les textes français passés à `tr('…')` dans les fichiers du lot B2 doivent avoir une traduction dans les sept autres langues
/// (en, es, de, ar, pt, zh, sw), différente du français sauf pour les noms propres.
const _files = [
  'lib/services/api/groups_b2_models.dart',
  'lib/services/api/notification_text.dart',
  'lib/services/api/paid_content_b2_models.dart',
  'lib/services/api/post_social_models.dart',
  'lib/widgets/post_social_actions.dart',
  'lib/pages/chat/group/group_earnings_page.dart',
  'lib/pages/chat/group/group_revenue_card.dart',
  'lib/pages/admin/admin_groups_page.dart',
  'lib/pages/admin/group_block_dialog.dart',
  'lib/pages/contenuPayant/episode_page.dart',
  'lib/pages/contenuPayant/seriesDetailScreenContenu.dart',
  'lib/pages/contenuPayant/widgets/series_episodes_section.dart',
  'lib/pages/contenuPayant/widgets/promo_code_modal.dart',
  'lib/pages/contenuPayant/widgets/content_comments_section.dart',
];

/// Mots identiques dans toutes les langues (noms propres ou symboles).
const _sameEverywhere = {'Afrolook', 'Mentions', '{n} pages'};

const _langs = ['en', 'es', 'de', 'ar', 'pt', 'zh', 'sw'];

Set<String> _literals(String source) {
  final out = <String>{};
  final re = RegExp(r"\btr\(\s*'((?:\\.|[^'\\])*)'");
  for (final m in re.allMatches(source)) {
    out.add(m.group(1)!.replaceAll(r"\'", "'"));
  }
  return out;
}

void main() {
  test('chaque texte du lot B2 est traduit dans les sept langues', () {
    final missing = <String>[];
    var total = 0;
    for (final path in _files) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: path);
      for (final fr in _literals(file.readAsStringSync())) {
        total++;
        if (_sameEverywhere.contains(fr)) continue;
        for (final lang in _langs) {
          final t = trFor(lang, fr, {'n': 1, 'p': 'x', 'm': 'x', 'c': 'x'});
          final plain = trFor('fr', fr, {'n': 1, 'p': 'x', 'm': 'x', 'c': 'x'});
          if (t == plain) missing.add('[$lang] $fr');
        }
      }
    }
    expect(total, greaterThan(60));
    expect(missing, isEmpty, reason: 'traductions manquantes :\n${missing.join('\n')}');
  });

  test('les entrées du dictionnaire du lot B2 gardent leurs paramètres dans toutes les langues', () {
    final src = File('lib/l10n/tr_b2.dart').readAsStringSync();
    final entries = RegExp(r"^\s*'((?:\\.|[^'\\])*)': \{(.*)\},\s*$", multiLine: true).allMatches(src).toList();
    expect(entries.length, greaterThan(100));
    final param = RegExp(r'\{[a-z]\}');
    for (final m in entries) {
      final fr = m.group(1)!.replaceAll(r"\'", "'");
      final params = param.allMatches(fr).map((e) => e.group(0)).toSet();
      for (final lang in _langs) {
        final t = trFor(lang, fr);
        for (final p in params) {
          expect(t, contains(p!), reason: '[$lang] $fr');
        }
      }
    }
  });

  test('le français reste le texte d\'origine, une langue inconnue retombe sur l\'anglais', () {
    expect(trFor('fr', 'Publication republiée ✓'), 'Publication republiée ✓');
    expect(trFor('en', 'Publication republiée ✓'), 'Post reposted ✓');
    expect(trFor('xx', 'Publication republiée ✓'), 'Post reposted ✓');
    expect(trFor('en', '🎉 Merci ! Le créateur a reçu {n} pièce.', {'n': 1}), '🎉 Thank you! The creator received 1 coin.');
  });
}
