import 'package:afrotok/pages/videos/video_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Barre du haut des vidéos portrait : le total des interactions (à droite) ne doit pas avoir le double trait jaune
/// que Flutter met sous un texte sans Material (la page vidéo n'a pas de Scaffold sur téléphone).
void main() {
  testWidgets('le texte placé à droite de la barre n\'est pas souligné', (t) async {
    // MaterialApp sans Scaffold, comme la page vidéo sur téléphone : le style par défaut est celui « d'erreur » (trait jaune)
    await t.pumpWidget(MaterialApp(
      home: Stack(children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: VideoTopBar(index: 1, onChanged: (_) {}, trailing: const Text('1,2 k', key: ValueKey('total'))),
        ),
      ]),
    ));
    final style = DefaultTextStyle.of(t.element(find.byKey(const ValueKey('total')))).style;
    expect(style.decoration ?? TextDecoration.none, TextDecoration.none);
  });
}
