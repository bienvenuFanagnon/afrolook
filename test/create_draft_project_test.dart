import 'dart:io';

import 'package:afrotok/services/create_draft.dart';
import 'package:afrotok/services/studio_project.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePaths extends Fake with MockPlatformInterfaceMixin implements PathProviderPlatform {
  _FakePaths(this.dir);
  final String dir;
  @override
  Future<String?> getApplicationDocumentsPath() async => dir;
  @override
  Future<String?> getTemporaryPath() async => dir;
}

/// Brouillons (09/11/2026) : les réglages en attente du rendu en une passe (découpe, vitesse, voix, sous-titres) sont gardés et restitués à la reprise.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('draft_test');
    PathProviderPlatform.instance = _FakePaths(tmp.path);
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  test('un brouillon enregistré avec des réglages en attente les restitue tels quels à la reprise', () async {
    final media = File('${tmp.path}/clip.mp4')..writeAsBytesSync([1, 2, 3, 4]);
    final project = StudioProject(trimStartMs: 2000, trimEndMs: 8000, speed: 'fast2', voice: 'deep', subtitles: const [ProjectCue(500, 1500, 'Bonjour'), ProjectCue(3000, 4000, 'Salut')]);
    await CreateDraft.save(path: media.path, isVideo: true, source: 'edited', voiceEffect: 'deep', touched: true, project: project);
    final d = await CreateDraft.load();
    expect(d, isNotNull);
    final p = d!.project!;
    expect([p.trimStartMs, p.trimEndMs, p.speed, p.voice], [2000, 8000, 'fast2', 'deep']);
    expect(p.subtitles.map((c) => [c.startMs, c.endMs, c.text]).toList(), [[500, 1500, 'Bonjour'], [3000, 4000, 'Salut']]);
    // la conversion vers le serveur est la même avant et après le brouillon
    expect(p.toApi(), project.toApi());
  });

  test('sans réglage en attente : le brouillon n\'a pas de projet ; un projet abîmé est ignoré sans erreur', () async {
    final media = File('${tmp.path}/clip.mp4')..writeAsBytesSync([1, 2, 3]);
    await CreateDraft.save(path: media.path, isVideo: true, source: 'edited', project: StudioProject());
    expect((await CreateDraft.load())!.project, isNull);
    expect(StudioProject.fromJson('n\'importe quoi').isEmpty, isTrue);
    expect(StudioProject.fromJson({'trim_start_ms': 1000}).hasTrim, isFalse);   // une borne seule est ignorée
    expect(StudioProject.fromJson({'speed': 'reverse', 'subtitles': [{'text': 'x'}]}).isEmpty, isTrue);
  });
}
