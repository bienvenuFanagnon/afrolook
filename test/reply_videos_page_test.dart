import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/userPosts/reply_videos_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, Brightness b) => MaterialApp(theme: ThemeData(brightness: b), locale: const Locale('fr'), localizationsDelegates: GlobalMaterialLocalizations.delegates, supportedLocales: const [Locale('fr')], home: child);

void main() {
  for (final b in [Brightness.light, Brightness.dark]) {
    testWidgets('réponses en vidéo (${b.name}) : liste, vide, erreur avec Réessayer', (tester) async {
      final p = Post()..id = 'p1'..description = 'Voici ma recette !'..user = (UserData()..pseudo = 'awa');
      await tester.pumpWidget(_host(ReplyVideosPage(postId: 'x', loader: (_) async => [p]), b));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('replies_list')), findsOneWidget);
      expect(find.text('@awa'), findsOneWidget);
      expect(find.text('Voici ma recette !'), findsOneWidget);

      await tester.pumpWidget(_host(ReplyVideosPage(key: const ValueKey('b'), postId: 'y', loader: (_) async => []), b));
      await tester.pumpAndSettle();
      expect(find.textContaining('Personne'), findsOneWidget);

      var calls = 0;
      await tester.pumpWidget(_host(ReplyVideosPage(key: const ValueKey('c'), postId: 'z', loader: (_) async {
        calls++;
        if (calls == 1) throw StateError('réseau');
        return [p];
      }), b));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('replies_retry')));
      await tester.pumpAndSettle();
      expect(find.text('@awa'), findsOneWidget);
    });
  }
}
