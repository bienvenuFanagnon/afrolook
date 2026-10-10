import 'dart:io';

import 'package:afrotok/pages/cards/card_events.dart';
import 'package:afrotok/pages/cards/card_models.dart';
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
}
