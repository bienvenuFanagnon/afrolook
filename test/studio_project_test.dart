import 'package:afrotok/services/studio_project.dart';
import 'package:flutter_test/flutter_test.dart';

/// Éditeur unique (rendu en une passe) : les réglages restent en attente et partent ensemble au serveur.
void main() {
  test('un projet vide ne dit rien ; chaque réglage le rend non vide', () {
    final p = StudioProject();
    expect(p.isEmpty, isTrue);
    expect(p.toApi(), isEmpty);
    expect((StudioProject()..voice = 'deep').isNotEmpty, isTrue);
    expect((StudioProject()..speed = 'slow').isNotEmpty, isTrue);
    expect((StudioProject(trimStartMs: 1000, trimEndMs: 5000)).hasTrim, isTrue);
  });

  test('durée du film final : découpe puis vitesse (comme le serveur)', () {
    expect(StudioProject(trimStartMs: 2000, trimEndMs: 8000, speed: 'fast2').finalMs(10000), 3000);
    expect(StudioProject(speed: 'slow').finalMs(10000), 20000);
    expect(StudioProject(trimStartMs: 0, trimEndMs: 99000).finalMs(10000), 10000);   // fin au-delà de la vidéo : coupée
  });

  test('les sous-titres passent du temps de la vidéo d\'origine au temps du film final (découpe puis vitesse) et ceux hors passage disparaissent', () {
    final p = StudioProject(trimStartMs: 2000, trimEndMs: 8000, speed: 'fast2', subtitles: const [
      ProjectCue(500, 1500, 'avant le passage'),   // entièrement avant : retiré
      ProjectCue(3000, 4000, 'dedans'),            // (3000−2000)/2 = 500 → (4000−2000)/2 = 1000
      ProjectCue(7000, 9000, 'déborde'),           // fin ramenée à 8000 → (8000−2000)/2 = 3000
      ProjectCue(8500, 9000, 'après'),             // entièrement après : retiré
    ]);
    final api = p.toApi();
    expect(api['trim'], {'start_ms': 2000, 'end_ms': 8000});
    expect(api['speed'], 'fast2');
    final cues = api['subtitles'] as List;
    expect(cues.length, 2);
    expect(cues[0], {'start_ms': 500, 'end_ms': 1000, 'text': 'dedans'});
    expect(cues[1], {'start_ms': 2500, 'end_ms': 3000, 'text': 'déborde'});
  });

  test('ralenti : les sous-titres s\'étirent ; sans découpe ils restent à leur place', () {
    final p = StudioProject(speed: 'slow', subtitles: const [ProjectCue(1000, 2000, 'a')]);
    expect((p.toApi()['subtitles'] as List).single, {'start_ms': 2000, 'end_ms': 4000, 'text': 'a'});
    final q = StudioProject(subtitles: const [ProjectCue(1000, 2000, 'a')]);
    expect((q.toApi()['subtitles'] as List).single, {'start_ms': 1000, 'end_ms': 2000, 'text': 'a'});
    expect(q.toApi().containsKey('trim'), isFalse);
  });

  test('copie indépendante (pour « Annuler »)', () {
    final p = StudioProject(voice: 'deep', subtitles: const [ProjectCue(0, 1000, 'a')]);
    final c = p.copy()
      ..voice = 'high'
      ..subtitles.add(const ProjectCue(1000, 2000, 'b'));
    expect(p.voice, 'deep');
    expect(p.subtitles.length, 1);
    expect(c.subtitles.length, 2);
  });

  test('interrupteur : éteint par défaut ; lu depuis {enabled: true} ou true', () {
    expect(SinglePassConfig.enabled, isFalse);
    expect(SinglePassConfig.parse(null), isFalse);
    expect(SinglePassConfig.parse({'enabled': false}), isFalse);
    expect(SinglePassConfig.parse({'enabled': true}), isTrue);
    expect(SinglePassConfig.parse(true), isTrue);
    expect(SinglePassConfig.parse('oui'), isFalse);
  });
}
