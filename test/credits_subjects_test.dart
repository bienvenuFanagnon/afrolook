import 'package:afrotok/pages/studio/montage/credits_subjects.dart';
import 'package:afrotok/pages/studio/montage/montage_catalog.dart';
import 'package:afrotok/pages/studio/montage/montage_music.dart';
import 'package:afrotok/pages/studio/montage/story_script.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dix sujets, un modèle de générique du catalogue chacun', () {
    expect(kCreditsSubjects.length, 10);
    expect({for (final s in kCreditsSubjects) s.templateId}, kCreditsTemplateIds);
    for (final s in kCreditsSubjects) {
      final t = kMontageTemplates.where((x) => x.id == s.templateId);
      expect(t.length, 1, reason: s.templateId);
      expect(t.first.isCredits, isTrue, reason: s.templateId);
      expect(t.first.music, s.music, reason: '${s.templateId} : musique du modèle ≠ musique du sujet');
      expect(studioTrack(s.music), isNotNull, reason: '${s.templateId} : piste « ${s.music} » introuvable');
    }
  });

  test('chaque style donne un générique complet qui se termine par FIN', () {
    for (final s in kCreditsSubjects) {
      final classique = s.lines(CreditsStyle.classique);
      final longue = s.lines(CreditsStyle.chapitres);
      expect(classique.first, startsWith('# '), reason: s.templateId);
      expect(classique.last, '# FIN', reason: s.templateId);
      expect(longue.last, '# FIN', reason: s.templateId);
      expect(longue.length, greaterThan(classique.length + s.chapters.length), reason: '${s.templateId} : la version longue doit être plus longue');
      expect(longue.first, '# ${s.bigChapters}', reason: s.templateId);
      for (final c in s.chapters) {
        expect(longue, contains('${c.$1} · ${c.$2}'), reason: s.templateId);
      }
    }
  });

  test('Mon année garde l’année qui finit dans le titre', () {
    final annee = creditsSubjectFor('fa_film')!;
    expect(annee.title, matches(RegExp(r'^MON ANNÉE 20\d\d$')));
    expect(creditsSubjectFor('inconnu'), isNull);
    expect(creditsDefaultLinesFor('inconnu').first, startsWith('# MON ANNÉE'));
  });

  test('les modèles de générique sont en vidéo et nouveaux (catégorie « Ma vie »)', () {
    for (final id in kCreditsTemplateIds.where((i) => i != 'fa_film')) {
      final t = kMontageTemplates.firstWhere((x) => x.id == id);
      expect(t.cat, MontageCat.vie);
      expect(t.showsVideo, isTrue);
      expect(t.name, isNotEmpty);
    }
  });
}
