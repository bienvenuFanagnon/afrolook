import 'package:afrotok/pages/studio/montage/montage_catalog.dart';
import 'package:afrotok/pages/studio/montage/montage_look.dart';
import 'package:afrotok/pages/studio/montage/montage_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('un montage démarre sans effet animé : calque d\'effet masqué, rien ne bouge, même pour un modèle à effet', () {
    final withFx = kMontageTemplates.where((t) => t.fx != MontageFx.none).toList();
    expect(withFx, isNotEmpty);
    for (final t in kMontageTemplates) {
      final s = MontageState(t);
      expect(s.animated, isFalse, reason: t.id);
      expect(s.hidden, contains(MontageLayer.fx), reason: t.id);
      expect(s.fxActive, isFalse, reason: t.id);
    }
    // sans musique ni vidéo de base, le résultat est une image fixe
    final s = MontageState(withFx.first)..music = null;
    expect(s.exportsVideo, isFalse);
  });

  test('la personne peut réactiver l\'effet : le calque redevient actif et le montage devient une vidéo animée', () {
    final t = kMontageTemplates.firstWhere((t) => t.fx != MontageFx.none);
    final s = MontageState(t)..music = null;
    s.hidden.remove(MontageLayer.fx);
    s.animated = true;
    expect(s.fxActive, isTrue);
    expect(s.exportsVideo, isTrue);
  });

  test('un look remplace la saturation et la luminosité du modèle ; sans look, le modèle garde les siennes', () {
    final t = kMontageTemplates.firstWhere((t) => t.saturation != 1 || t.brightness != 0, orElse: () => kMontageTemplates.first);
    final s = MontageState(t);
    expect(s.saturation, t.saturation);
    expect(s.brightness, t.brightness);
    s.look = kMontageLooks.firstWhere((l) => l.id == 'mono');
    expect(s.saturation, 0);
    s.look = kMontageLooks.firstWhere((l) => l.id == 'vivid');
    expect(s.saturation, greaterThan(1));
    s.look = null;
    expect(s.saturation, t.saturation);
  });

  test('les looks sont sobres : identifiants uniques, valeurs raisonnables, aucune animation', () {
    final ids = kMontageLooks.map((l) => l.id).toSet();
    expect(ids.length, kMontageLooks.length);
    for (final l in kMontageLooks) {
      expect(l.saturation, inInclusiveRange(0, 1.5), reason: l.id);
      expect(l.brightness, inInclusiveRange(-.2, .2), reason: l.id);
    }
  });
}
