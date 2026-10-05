import 'package:afrotok/pages/etude/etude_diploma_page.dart';
import 'package:afrotok/services/etude/etude_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test("l'état d'Étude se lit depuis la réponse du serveur", () {
    final s = EtudeState.fromMap({
      'xp': 120,
      'level': 2,
      'streak': 3,
      'levels': {'td_maths_suites': 2},
      'classes': {'lyc_td': {'pct': 80, 'at': 1}},
      'unlocked': {'ch:a': true},
      'adsPaid': {'ch:b': 2},
      'diplomas': [
        {'title': 'BAC D', 'serial': 'AFR-AAAA0001', 'pct': 80, 'at': 2, 'kind': 'exam', 'track': 'lycee_d'},
      ],
      'tracks': {
        'lycee_d': {
          'entry': 'lyc_td',
          'classes': {
            'lyc_td': {'status': 'validated', 'done': 9, 'total': 9, 'pct': 80},
            'lyc_2nde': {'status': 'skipped', 'done': 0, 'total': 0},
          },
          'examReady': true,
          'diploma': null,
        },
      },
      'config': {'adValueCoins': 3, 'chapterPrice': 20, 'prices': {'ch:vip': 50}},
    });
    expect(s.level, 2);
    expect(s.tracks['lycee_d']!.examReady, true);
    expect(s.tracks['lycee_d']!.classes['lyc_td']!.pct, 80);
    expect(s.priceOf('ch:x'), 20);
    expect(s.priceOf('ch:vip'), 50);
    expect(s.priceOf('exam:lycee_d'), 60);
    // 20 pièces à 3 pièces par pub : 7 pubs
    expect(s.adsFor(20), 7);
    expect(s.adsFor(3), 1);
  });

  test('un parcours se lit depuis le catalogue', () {
    final t = EtudeTrack.fromMap({
      'id': 'lycee_d',
      'kind': 'cycle',
      'title': 'Lycée — série D',
      'order': 20,
      'after': ['college'],
      'classes': [
        {
          'id': 'lyc_td',
          'title': 'Terminale D',
          'subjects': [
            {
              'id': 'maths',
              'title': 'Mathématiques',
              'icon': 'calculate',
              'chapters': [
                {'id': 'td_maths_suites', 'title': 'Suites', 'levels': 3, 'free': true},
                {'id': 'td_maths_ln', 'title': 'Logarithme', 'levels': 3},
              ],
            },
          ],
        },
      ],
      'exam': {'id': 'bac_d', 'title': 'Examen du BAC D'},
    });
    expect(t.classes.single.chapters.length, 2);
    expect(t.classes.single.chapters.first.free, true);
    expect(t.after, ['college']);
  });

  testWidgets('le diplôme s\'affiche', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: EtudeDiplomaPage(diploma: const {'title': 'BAC D — Baccalauréat, série D', 'serial': 'AFR-AAAA0001', 'pct': 82, 'at': 1700000000000, 'kind': 'exam'}),
    ));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('BAC D'), findsWidgets);
    expect(find.text('AFR-AAAA0001'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
