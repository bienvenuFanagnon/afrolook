import 'package:afrotok/pages/studio/artist_marketplace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Validation d'un son par l'équipe (08/11/2026) : le bouton ne tourne plus dans le vide. Message de confirmation ou d'erreur, et la fiche traitée quitte la liste.
ArtistSound _sound(String id, {String status = 'pending_review', Object? processed = true}) => ArtistSound(
      id: id,
      userId: 'u1',
      userPseudo: 'awa',
      userImageUrl: '',
      title: 'Titre $id',
      durationMs: 60000,
      status: status,
      usageCount: 0,
      totalEarningsCoins: 0,
      processed: processed,
      createdAt: DateTime(2026, 11, 8),
    );

Widget _app(Widget page, {Brightness b = Brightness.light}) => MaterialApp(
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(brightness: b),
      home: page,
    );

void main() {
  testWidgets('valider un son : message de confirmation, la fiche quitte la liste « À valider »', (tester) async {
    var queue = [_sound('a'), _sound('b')];
    final calls = <String>[];
    await tester.pumpWidget(_app(AdminArtistSoundsPage(
      loadQueue: () async => List.of(queue),
      review: (id, action, {reason}) async {
        calls.add('$id:$action');
        queue = queue.where((s) => s.id != id).toList();   // le serveur la passe en « validated »
      },
    )));
    await tester.pumpAndSettle();
    expect(find.text('Titre a'), findsOneWidget);
    expect(find.text('Titre b'), findsOneWidget);

    await tester.tap(find.text('Valider').first);
    await tester.pumpAndSettle();

    expect(calls, ['a:validate']);
    expect(find.textContaining('Son validé'), findsOneWidget);   // la confirmation est dite
    expect(find.text('Titre a'), findsNothing);                   // la fiche traitée n'est plus là
    expect(find.text('Titre b'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('erreur du serveur : message rouge, la fiche reste et le bouton redevient utilisable', (tester) async {
    await tester.pumpWidget(_app(AdminArtistSoundsPage(
      loadQueue: () async => [_sound('a')],
      review: (id, action, {reason}) async => throw Exception('hors ligne'),
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);                // jamais un bouton qui tourne puis s'arrête sans rien
    expect(find.text('Titre a'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Valider'), findsOneWidget);
  });

  testWidgets('analyse pas encore prête : « Valider » est désactivé tant que le serveur n\'a pas traité le son', (tester) async {
    await tester.pumpWidget(_app(AdminArtistSoundsPage(loadQueue: () async => [_sound('a', processed: null)], review: (id, action, {reason}) async {})));
    await tester.pumpAndSettle();
    final btn = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Valider'));
    expect(btn.onPressed, isNull);
    expect(find.textContaining('Analyse en cours'), findsOneWidget);
  });

  testWidgets('chargement en échec : message et bouton Réessayer, en clair comme en sombre', (tester) async {
    for (final b in [Brightness.light, Brightness.dark]) {
      var n = 0;
      await tester.pumpWidget(_app(AdminArtistSoundsPage(key: UniqueKey(), loadQueue: () async {
        n++;
        if (n == 1) throw Exception('hors ligne');
        return [_sound('a')];
      }, review: (id, action, {reason}) async {}), b: b));
      await tester.pumpAndSettle();
      expect(find.text('Réessayer'), findsWidgets);
      await tester.tap(find.text('Réessayer').first);
      await tester.pumpAndSettle();
      expect(find.text('Titre a'), findsOneWidget);
    }
  });
}
