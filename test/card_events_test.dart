import 'dart:io';

import 'package:afrotok/pages/cards/card_events.dart';
import 'package:afrotok/pages/cards/card_models.dart';
import 'package:afrotok/pages/studio/montage/montage_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fête nationale : le jour dit, pour les gens de ce pays seulement', () {
    final e = CardEvents.forToday('TG', DateTime(2027, 4, 27))!;
    expect(e.id, 'national-TG-2027');
    expect(e.flagFree, true);
    expect(e.country, 'TG');
    expect(e.style.usesFlag, true);
    expect(e.text.contains('#fetenationale'), true);
    expect(e.text.contains('#togo'), true);
    expect(CardEvents.forToday('SN', DateTime(2027, 4, 27))?.flagFree, isNot(true)); // 27 avril : pas le Sénégal (4 avril)
    expect(CardEvents.forToday('NG', DateTime(2026, 10, 1))!.country, 'NG');
    expect(CardEvents.forToday('XX', DateTime(2026, 10, 1)), isNull);
    expect(CardEvents.forToday(null, DateTime(2026, 10, 1)), isNull);
  });

  test('un jour sans fête : rien', () {
    expect(CardEvents.forToday('TG', DateTime(2026, 10, 11)), isNull);
    expect(CardEvents.forToday(null, DateTime(2026, 10, 11)), isNull);
  });

  test('fêtes internationales : Noël, Nouvel An (une seule invitation sur deux jours), Saint-Valentin, Afrique', () {
    expect(CardEvents.forToday(null, DateTime(2026, 12, 25))!.id, 'noel-2026');
    expect(CardEvents.forToday(null, DateTime(2026, 12, 24))!.id, 'noel-2026');
    expect(CardEvents.forToday(null, DateTime(2026, 12, 31))!.id, 'newyear-2027');
    expect(CardEvents.forToday(null, DateTime(2027, 1, 1))!.id, 'newyear-2027');
    expect(CardEvents.forToday(null, DateTime(2027, 2, 14))!.id, 'valentin-2027');
    expect(CardEvents.forToday(null, DateTime(2027, 5, 25))!.id, 'africaday-2027');
  });

  test('fêtes mobiles : Pâques, fête des mères, fête des pères, Aïd', () {
    expect(CardEvents.easter(2026), DateTime(2026, 4, 5));
    expect(CardEvents.easter(2027), DateTime(2027, 3, 28));
    expect(CardEvents.forToday(null, DateTime(2027, 3, 28))!.id, 'paques-2027');
    expect(CardEvents.nthWeekday(2026, 5, DateTime.sunday, 2), DateTime(2026, 5, 10));
    expect(CardEvents.forToday(null, DateTime(2026, 5, 10))!.id, 'meres-2026');
    expect(CardEvents.forToday(null, DateTime(2026, 6, 21))!.id, 'peres-2026');
    expect(CardEvents.forToday(null, DateTime(2027, 3, 10))!.id, 'fitr-2027');
    expect(CardEvents.forToday(null, DateTime(2027, 3, 11))!.id, 'fitr-2027'); // le lendemain aussi
    expect(CardEvents.forToday(null, DateTime(2027, 5, 17))!.id, 'adha-2027');
  });

  test('la fête nationale passe avant les fêtes internationales (Libye : 24 décembre)', () {
    expect(CardEvents.forToday('LY', DateTime(2026, 12, 24))!.id, 'national-LY-2026');
    expect(CardEvents.forToday('LY', DateTime(2026, 12, 25))!.id, 'noel-2026');
  });

  test('la table des fêtes nationales est la même que celle du serveur', () {
    final ts = File('functions/src/cards/cards.ts').readAsStringSync();
    final block = RegExp(r'NATIONAL_DAYS[^=]*=\s*\{(.*?)\n\};', dotAll: true).firstMatch(ts)!.group(1)!;
    final server = <String, (int, int)>{};
    for (final m in RegExp(r'([A-Z]{2}): \[(\d+), (\d+)\]').allMatches(block)) {
      server[m.group(1)!] = (int.parse(m.group(2)!), int.parse(m.group(3)!));
    }
    expect(CardEvents.nationalDays, server);
    expect(server.length, greaterThan(55));
  });

  testWidgets('l\'invitation montre le titre, l\'offre drapeau et le bouton', (t) async {
    final e = CardEvents.forToday('TG', DateTime(2027, 4, 27))!;
    await t.pumpWidget(MaterialApp(home: Scaffold(body: CardEventDialog(event: e))));
    await t.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('fête nationale'), findsWidgets);
    expect(find.text('Créer ma carte'), findsOneWidget);
    expect(find.text('Plus tard'), findsOneWidget);
    expect(find.textContaining('drapeau offerts'), findsOneWidget);
  });

  group('fêtes qui approchent (3 jours ou moins)', () {
    int? left(String? country, DateTime d) => CardEvents.upcoming(country, d)?.daysLeft;

    test('Noël est compté jusqu\'au 25, pas jusqu\'à la veille', () {
      expect(left(null, DateTime(2026, 12, 21)), isNull); // 4 jours : trop tôt
      expect(left(null, DateTime(2026, 12, 22)), 3);
      expect(left(null, DateTime(2026, 12, 23)), 2);
      expect(left(null, DateTime(2026, 12, 24)), 1);
      expect(left(null, DateTime(2026, 12, 25)), 0);
      expect(CardEvents.upcoming(null, DateTime(2026, 12, 22))!.kind, 'noel');
    });

    test('Nouvel An : jusqu\'au 1er janvier', () {
      expect(left(null, DateTime(2026, 12, 29)), 3);
      expect(left(null, DateTime(2026, 12, 31)), 1);
      expect(left(null, DateTime(2027, 1, 1)), 0);
    });

    test('fête nationale du pays de la personne, Saint-Valentin, fête des mères, Aïd', () {
      expect(left('TG', DateTime(2027, 4, 24)), 3);
      expect(left('TG', DateTime(2027, 4, 27)), 0);
      expect(left('SN', DateTime(2027, 4, 24)), isNull); // le Sénégal fête le 4 avril
      expect(left(null, DateTime(2027, 2, 11)), 3);
      expect(left(null, DateTime(2027, 2, 10)), isNull);
      expect(left(null, DateTime(2026, 5, 8)), 2); // fête des mères le 10 mai 2026
      expect(left(null, DateTime(2028, 2, 24)), 3); // Aïd el-Fitr 2028 (27 février)
      expect(left(null, DateTime(2028, 2, 28)), 0); // le lendemain : encore là
      expect(CardEvents.upcoming(null, DateTime(2027, 3, 7))!.kind, 'femmes'); // le 8 mars passe avant l'Aïd du 10 mars
    });

    test('hors fête : rien ; l\'heure du jour ne change pas le décompte', () {
      expect(CardEvents.upcoming('TG', DateTime(2026, 10, 11)), isNull);
      expect(left(null, DateTime(2026, 12, 22, 23, 59)), 3);
    });

    test('titre : « Noël dans 3 jours », « demain », ou le titre de la fête le jour J', () {
      expect(CardEvents.upcoming(null, DateTime(2026, 12, 22))!.headline, 'Noël dans 3 jours');
      expect(CardEvents.upcoming(null, DateTime(2026, 12, 24))!.headline, 'Noël demain');
      expect(CardEvents.upcoming(null, DateTime(2026, 12, 25))!.headline, 'Joyeux Noël !');
    });

    test('chaque type de fête a un template du Studio qui existe', () {
      final days = {
        'national': ('TG', DateTime(2027, 4, 27)), 'africaday': (null, DateTime(2027, 5, 25)), 'fitr': (null, DateTime(2027, 3, 10)), 'adha': (null, DateTime(2027, 5, 17)),
        'newyear': (null, DateTime(2027, 1, 1)), 'noel': (null, DateTime(2026, 12, 25)), 'valentin': (null, DateTime(2027, 2, 14)), 'femmes': (null, DateTime(2027, 3, 8)),
        'travail': (null, DateTime(2027, 5, 1)), 'paques': (null, DateTime(2027, 3, 28)), 'meres': (null, DateTime(2026, 5, 10)), 'peres': (null, DateTime(2026, 6, 21)),
      };
      for (final e in days.entries) {
        final soon = CardEvents.upcoming(e.value.$1, e.value.$2);
        expect(soon, isNotNull, reason: e.key);
        expect(soon!.kind, e.key);
        expect(kMontageTemplates.any((t) => t.id == soon.studioTemplateId), isTrue, reason: '${e.key} → ${soon.studioTemplateId}');
      }
    });
  });

  testWidgets('invitation d\'une fête qui approche : titre « dans 3 jours », template et carte, pas d\'offre drapeau', (t) async {
    final soon = CardEvents.upcoming('TG', DateTime(2027, 4, 24))!;
    await t.pumpWidget(MaterialApp(home: Scaffold(body: CardEventDialog(event: soon.event, daysLeft: soon.daysLeft, headline: soon.headline, templateId: soon.studioTemplateId))));
    await t.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('dans 3 jours'), findsOneWidget);
    expect(find.text('Créer un post avec le template'), findsOneWidget);
    expect(find.text('Créer ma carte'), findsOneWidget);
    expect(find.textContaining('drapeau offerts'), findsNothing); // l'offre n'existe que le jour J
    expect(find.textContaining('à l\'avance'), findsOneWidget);
  });
}
