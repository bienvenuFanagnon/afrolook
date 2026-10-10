import 'package:afrotok/widgets/link_preview_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('firstLinkIn : premier lien, sans ponctuation finale', () {
    expect(firstLinkIn('Regarde https://youtu.be/abc, super #video'), 'https://youtu.be/abc');
    expect(firstLinkIn('(https://www.tiktok.com/@a/video/1).'), 'https://www.tiktok.com/@a/video/1');
    expect(firstLinkIn('pas de lien'), isNull);
    expect(firstLinkIn(null), isNull);
  });

  testWidgets('la carte montre site, titre, auteur, description et la croix', (tester) async {
    var removed = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LinkPreviewCard(
          data: const {'url': 'https://www.youtube.com/watch?v=x', 'title': 'Un titre', 'description': 'Une description', 'siteName': 'YouTube', 'author': 'Une chaîne', 'image': '', 'isVideo': true},
          onRemove: () => removed = true,
        ),
      ),
    ));
    expect(find.text('YOUTUBE'), findsOneWidget);
    expect(find.text('Un titre'), findsOneWidget);
    expect(find.text('Une chaîne'), findsOneWidget);
    expect(find.text('Une description'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded));
    expect(removed, true);
  });

  testWidgets('un lien qui n\'est pas http(s) n\'affiche rien', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: LinkPreviewCard(data: {'url': 'javascript:alert(1)', 'title': 'x'}))));
    expect(find.text('x'), findsNothing);
  });
}
