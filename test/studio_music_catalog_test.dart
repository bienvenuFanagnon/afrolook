import 'package:flutter_test/flutter_test.dart';

import 'package:afrotok/pages/studio/montage/montage_catalog.dart';
import 'package:afrotok/pages/studio/montage/montage_music.dart';

void main() {
  test('chaque piste gratuite a un identifiant valable pour R2 et unique', () {
    final ids = <String>{};
    for (final t in kStudioTracks) {
      expect(RegExp(r'^[a-z0-9_]{2,40}$').hasMatch(t.id), isTrue, reason: 'identifiant invalide : ${t.id}');
      expect(ids.add(t.id), isTrue, reason: 'identifiant en double : ${t.id}');
      expect(t.durationMs, greaterThan(10000), reason: t.id);
    }
  });

  test('les musiques libres de droits sont rangées dans une catégorie connue et créditées', () {
    final libres = kStudioTracks.where((t) => t.libre).toList();
    expect(libres, isNotEmpty);
    for (final t in libres) {
      expect(kStudioGroups, contains(t.group), reason: '${t.id} : catégorie « ${t.group} » inconnue');
      expect(t.credit, contains('Kevin MacLeod'));
      expect(MontageMusic.free(t).subtitle, contains('CC BY 4.0'));
    }
    // les pistes d'Afrolook n'ont pas de crédit et tombent aussi dans une catégorie connue
    for (final t in kStudioTracks.where((t) => !t.libre)) {
      expect(t.credit, isNull);
      expect(kStudioGroups, contains(t.section), reason: '${t.id} : catégorie « ${t.section} » inconnue');
    }
    expect(kLibreCredit, contains('creativecommons.org/licenses/by/4.0'));
  });

  test('chaque catégorie du sélecteur contient au moins une piste', () {
    for (final g in kStudioGroups) {
      expect(kStudioTracks.where((t) => t.section == g), isNotEmpty, reason: g);
    }
  });

  test('la musique proposée d\'office à un modèle existe toujours dans le catalogue', () {
    for (final t in kMontageTemplates) {
      final m = t.music;
      if (m == null) continue;
      expect(studioTrack(m), isNotNull, reason: '${t.id} : piste « $m » introuvable');
    }
    for (final e in kTemplateMusicLibre.entries) {
      expect(kMontageTemplates.any((t) => t.id == e.key), isTrue, reason: 'modèle inconnu : ${e.key}');
      expect(studioTrack(e.value), isNotNull, reason: '${e.key} : piste « ${e.value} » introuvable');
    }
  });

  test("la recherche trouve une musique par titre, par catégorie et sans tenir compte des accents ; le filtre de catégorie restreint la liste", () {
    // par titre
    expect(filterStudioTracks(kStudioTracks, query: "eternal").map((t) => t.id), contains("eternal_hope"));
    // par catégorie, avec ou sans accent
    final noel = filterStudioTracks(kStudioTracks, query: "noel");
    expect(noel, isNotEmpty);
    expect([for (final t in noel) if (!(foldSearch(t.section).contains("noel") || foldSearch(t.title).contains("noel") || foldSearch(t.mood).contains("noel"))) t.id], isEmpty);
    // catégorie « Fin de film » : des musiques qui concluent un film, dont celle d'office du générique
    final fin = filterStudioTracks(kStudioTracks, group: "Fin de film");
    expect(fin.length, greaterThanOrEqualTo(6));
    expect(fin.map((t) => t.id), contains(kMontageTemplates.firstWhere((x) => x.id == "fa_film").music));
    // catégorie + recherche ensemble
    expect(filterStudioTracks(kStudioTracks, query: "reign", group: "Fin de film").map((t) => t.id), ["reign"]);
    expect(filterStudioTracks(kStudioTracks, query: "reign", group: "Noël"), isEmpty);
    // une recherche vide ne retire rien ; une recherche sans résultat rend une liste vide
    expect(filterStudioTracks(kStudioTracks).length, kStudioTracks.length);
    expect(filterStudioTracks(kStudioTracks, query: "zzzzzz"), isEmpty);
    expect(foldSearch("Noël Été"), "noel ete");
  });
}
