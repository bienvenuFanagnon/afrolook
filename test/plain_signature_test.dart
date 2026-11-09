import 'package:afrotok/l10n/tr_montage.dart';
import 'package:afrotok/pages/studio/montage/montage_catalog.dart';
import 'package:afrotok/pages/studio/montage/montage_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// Collage et diaporama passent par l'éditeur (08/11/2026) : montage « sans habillage », mais la signature (@pseudo ou #canal) reste visible d'office.
void main() {
  test('sans habillage : tous les calques sont masqués', () {
    expect(MontageState.plainHidden(), MontageLayer.values.toSet());
  });

  test('collage ou diaporama : seule la signature reste visible, tout le reste est masqué', () {
    final hidden = MontageState.plainHidden(signature: true);
    expect(hidden.contains(MontageLayer.pseudo), isFalse);
    expect(hidden.length, MontageLayer.values.length - 1);
    for (final l in MontageLayer.values.where((l) => l != MontageLayer.pseudo)) {
      expect(hidden.contains(l), isTrue, reason: '$l devrait rester masqué');
    }
  });

  test('la nouvelle phrase de la bannière « avec musique » est traduite en 7 langues', () {
    final e = kTrMontage["Avec musique : l'image devient une vidéo (7, 15, 30 ou 60 s)"];
    expect(e, isNotNull);
    for (final lang in ['en', 'es', 'de', 'ar', 'pt', 'zh', 'sw']) {
      expect(e![lang], isNotNull, reason: lang);
    }
  });
}
