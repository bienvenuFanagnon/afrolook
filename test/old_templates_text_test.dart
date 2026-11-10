import 'package:afrotok/pages/studio/montage/montage_catalog.dart';
import 'package:afrotok/pages/studio/montage/montage_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les anciens modèles (situations, émotions, Insta, musique, culture, fêtes) gardent tous leurs textes affichés :
/// le titre, le sur-titre, le texte et le badge sont ce qui les distingue les uns des autres.
void main() {
  const anciennes = {MontageCat.situations, MontageCat.emotions, MontageCat.insta, MontageCat.music, MontageCat.culture, MontageCat.fetes};

  test('un ancien modèle montre son sur-titre, son titre et son texte', () {
    final anciens = kMontageTemplates.where((t) => anciennes.contains(t.cat) && !kNewTemplateIds.contains(t.id) && !kNewTemplateCats.contains(t.cat) && !t.musicOverridden && t.id != kPlainTemplateId);
    expect(anciens.length, greaterThan(60));
    for (final t in anciens) {
      final h = MontageState.defaultHidden(t);
      for (final l in [MontageLayer.kick, MontageLayer.title, MontageLayer.wish, MontageLayer.brand, MontageLayer.stats]) {
        expect(h.contains(l), isFalse, reason: '${t.id} cache ${l.name}');
      }
    }
  });

  test('chaque ancien modèle a un titre propre (pas deux pareils)', () {
    final titres = <String>{};
    for (final t in kMontageTemplates.where((t) => anciennes.contains(t.cat) && t.title.isNotEmpty)) {
      expect(titres.add(t.title), isTrue, reason: 'titre en double : ${t.title}');
    }
  });
}
