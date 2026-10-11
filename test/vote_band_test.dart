import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:afrotok/pages/cards/card_canvas.dart';
import 'package:afrotok/pages/cards/card_models.dart';

void main() {
  testWidgets('carte de participation : bandeau « Vote pour moi » sans débordement', (tester) async {
    final key = GlobalKey();
    final spec = CardSpec(style: CardStyleId.neon, format: CardFormat.portrait)
      ..voteText = 'Vote pour moi'
      ..voteLink = cardPostLink('AbCdEfGhIjKlMnOpQrSt');
    final source = CardSource.draft(pseudo: 'awa', text: 'Ma participation au défi de la semaine, merci de voter pour moi !', imageBytes: const [], followers: 0, profileId: 'u1');
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: RepaintBoundary(key: key, child: CardCanvas(source: source, spec: spec))))));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    final size = tester.getSize(find.byType(CardCanvas));
    expect(size.width, 360);
    expect(size.height, 450 + 100);
    expect(spec.hasVote, isTrue);
    spec.voteText = '';
    expect(spec.hasVote, isFalse);
  });
}
