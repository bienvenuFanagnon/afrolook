import 'package:afrotok/widgets/canal_tag.dart';
import 'package:afrotok/widgets/name_tag.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('le badge de canal n\'a aucune bordure', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Column(children: [
        NameTag(label: '#virale.vibes'),
        CanalTag(label: '#virale.vibes', bordered: true),
      ])),
    ));
    final boxes = tester.widgetList<Container>(find.byType(Container)).map((c) => c.decoration).whereType<BoxDecoration>();
    expect(boxes.where((d) => d.border != null), isEmpty);
  });
}
