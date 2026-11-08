import 'package:flutter_test/flutter_test.dart';

import 'package:afrotok/pages/studio/montage/montage_catalog.dart';
import 'package:afrotok/pages/studio/montage/montage_state.dart';

void main() {
  MontageState make() => MontageState(kPlainTemplate);

  test('haut / bas : deux moitiés ; inversé, ta vidéo passe en haut', () {
    final s = make()..layout = 'tb';
    final f = s.layoutFracs!;
    expect(f.origin.top, 0);
    expect(f.me.top, greaterThan(.49));
    s.layoutSwap = true;
    expect(s.layoutFracs!.origin.top, greaterThan(.49));
    expect(s.layoutFracs!.me.top, 0);
  });

  test('côte à côte : la vidéo d\'origine à gauche', () {
    final f = (make()..layout = 'sbs').layoutFracs!;
    expect(f.origin.left, 0);
    expect(f.me.left, greaterThan(.49));
  });

  test('bandeau : jamais plus de 40 % de la hauteur, et sans disposition rien', () {
    final s = make()..layout = 'bar';
    expect(s.layoutFracs!.origin.height, lessThanOrEqualTo(.4));
    s.layout = null;
    expect(s.layoutFracs, isNull);
  });
}
