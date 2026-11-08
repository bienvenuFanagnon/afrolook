import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/models/post_widget.dart';
import 'package:afrotok/widgets/post_media_overlays.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget overlay) => MaterialApp(
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Scaffold(body: Center(child: SizedBox(width: 320, height: 480, child: Stack(children: [const Positioned.fill(child: ColoredBox(color: Colors.black)), Positioned.fill(child: overlay)])))),
    );

/// Les calques posés sur le média d'un post (widgets, vidéos épinglées) sont les mêmes dans le fil et dans les pages de détail (08/11).
void main() {
  testWidgets('un post du fil avec un sondage et une vidéo épinglée : les deux s\'affichent sur le média', (tester) async {
    final post = Post()
      ..id = 'p1'
      ..widgets = [PostWidget(id: 'w1', kind: WidgetKind.poll, config: {'question': 'Ton plat ?', 'options': ['Riz', 'Attiéké']})]
      ..studioPins = [
        {'post_id': 'orig', 'x': .8, 'y': .2, 'w': .3}
      ];
    await tester.pumpWidget(_app(PostMediaOverlays(post: post)));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('📊 Ton plat ?'), findsOneWidget);
    expect(find.byKey(const ValueKey('pin_open_orig')), findsOneWidget);
    expect(find.text('Voir l\'original'), findsOneWidget);
  });

  testWidgets('un post sans widget ni vidéo épinglée ne dessine rien', (tester) async {
    final post = Post()..id = 'p2';
    await tester.pumpWidget(_app(PostMediaOverlays(post: post)));
    expect(find.byType(PostMediaOverlays), findsOneWidget);
    expect(find.byKey(const ValueKey('pin_open_orig')), findsNothing);
    expect(find.textContaining('📊'), findsNothing);
  });
}
