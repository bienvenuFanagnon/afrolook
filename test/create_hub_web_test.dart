// Application web : on ne publie pas depuis le navigateur. L'écran « Que créer ? » n'affiche qu'un message.
// Ce test ne tourne que dans un navigateur : flutter test --platform chrome test/create_hub_web_test.dart
@TestOn('browser')
library;

import 'package:afrotok/pages/create/create_hub_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('sur le web, « Que créer ? » affiche un message et aucun bouton de création', (t) async {
    await t.pumpWidget(const MaterialApp(home: CreateHubPage()));
    await t.pump();
    expect(find.byKey(const ValueKey('hub_web_notice')), findsOneWidget);
    expect(find.text("Publie depuis l'application"), findsOneWidget);
    for (final k in ['tile_photo', 'tile_audio', 'tile_text', 'tile_card']) {
      expect(find.byKey(ValueKey(k)), findsNothing, reason: k);
    }
    // aucun bouton de création : ni la grande carte Vidéo, ni les tuiles
    expect(find.text('Photo'), findsNothing);
    expect(find.text('Audio'), findsNothing);
  });

  testWidgets('sur le web, une ouverture directe (« Filme-toi ») ne lance rien', (t) async {
    await t.pumpWidget(const MaterialApp(home: CreateHubPage(start: CreateStart.video)));
    await t.pump();
    expect(find.byKey(const ValueKey('hub_web_notice')), findsOneWidget);
    expect(find.byKey(const ValueKey('hub_opening')), findsNothing);
  });
}
