import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/create/create_publish_page.dart';
import 'package:afrotok/pages/create/create_result.dart';
import 'package:afrotok/services/post_source_link.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {Brightness b = Brightness.light}) => MaterialApp(
      theme: ThemeData(brightness: b),
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: child,
    );

UserData _user() => UserData()..countryData = {'countryCode': 'TG'};

void main() {
  tearDown(() {
    PostSourceLink.clear();
    PostVoiceLink.clear();
  });

  testWidgets('formulaire unique : aperçu, description, type, pays et Publier ; la publication part avec les valeurs choisies', (tester) async {
    String? sent;
    await tester.pumpWidget(_host(CreatePublishPage(kind: CreatePostKind.audio, audioSeconds: 48, me: _user(), publish: (d, t, c) async => sent = '$d|$t|${c.join(',')}')));
    expect(find.text('Nouveau post'), findsOneWidget);
    expect(find.byKey(const ValueKey('publish_preview')), findsOneWidget);
    expect(find.text('0:48'), findsOneWidget);
    expect(find.text('Type de publication'), findsOneWidget);
    expect(find.text('Pays'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('publish_desc')), 'Ma voix du jour');
    await tester.tap(find.byKey(const ValueKey('field_type')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('type_SPORT')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('publish_go')));
    await tester.pumpAndSettle();
    expect(sent, 'Ma voix du jour|SPORT|TG');
    expect(tester.takeException(), isNull);
  });

  testWidgets('un texte vide n\'est pas publié ; la mention « Fait sur Afrolook » et la voix modifiée s\'affichent dans la note', (tester) async {
    PostSourceLink.set(PostSourceLink.edited);
    PostVoiceLink.set('deep');
    var calls = 0;
    await tester.pumpWidget(_host(CreatePublishPage(kind: CreatePostKind.text, me: _user(), publish: (d, t, c) async => calls++)));
    expect(find.byKey(const ValueKey('publish_preview')), findsNothing);
    expect(find.byKey(const ValueKey('original_badge')), findsOneWidget);
    expect(find.textContaining('Voix modifiée'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('publish_go')));
    await tester.pump();
    expect(calls, 0);
    await tester.enterText(find.byKey(const ValueKey('publish_desc')), 'Bonjour');
    await tester.tap(find.byKey(const ValueKey('publish_go')));
    await tester.pumpAndSettle();
    expect(calls, 1);
  });

  testWidgets('plan gratuit : 1 seul pays ; thème sombre sans débordement', (tester) async {
    expect(createLimitsFor(_user()).countries, 1);
    expect(createLimitsFor(_user()).chars, 300);
    await tester.pumpWidget(_host(CreatePublishPage(kind: CreatePostKind.video, me: _user(), publish: (d, t, c) async {}), b: Brightness.dark));
    await tester.tap(find.byKey(const ValueKey('field_countries')));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 pays en version gratuite'), findsOneWidget);
    expect(find.byKey(const ValueKey('countries_all')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
