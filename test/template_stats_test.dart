import 'package:afrotok/models/post_widget.dart';
import 'package:afrotok/pages/studio/montage/montage_catalog.dart';
import 'package:afrotok/pages/studio/montage/montage_gallery_page.dart';
import 'package:afrotok/services/api/post_mapper.dart';
import 'package:afrotok/services/api/template_stats_api.dart';
import 'package:afrotok/services/template_link.dart';
import 'package:flutter_test/flutter_test.dart';

/// Modèles prêts à poster, étape 1 (09/11/2026) : compteur d'utilisations, classement « les plus utilisés », modèles qui posent des widgets d'office.
void main() {
  tearDown(() => TemplateStatsApi.setForTest(const []));

  test('« 18,2 k » au-delà de 1 000, le nombre tel quel en dessous', () {
    expect(TemplateStatsApi.format(0), '0');
    expect(TemplateStatsApi.format(999), '999');
    expect(TemplateStatsApi.format(1000), '1,0 k');
    expect(TemplateStatsApi.format(18200), '18,2 k');
  });

  test('le classement du serveur remonte : les plus utilisés en premier, les autres suivent dans l\'ordre du catalogue, « plain » jamais proposé', () {
    TemplateStatsApi.setForTest(const [TemplateUse('m:noel', 40, 12), TemplateUse('m:amour', 90, 3), TemplateUse('c:neon', 5, 5)]);
    final list = popularMontageTemplates();
    // les nouveautés d'abord (tant qu'elles sont récentes), puis le classement du serveur
    final nouveautes = newMontageTemplates().length;
    expect(list.take(nouveautes).every((t) => t.isNew), isTrue);
    final rest = list.skip(nouveautes).toList();
    expect(rest.first.id, 'noel');
    expect(rest[1].id, 'amour');
    expect(list.any((t) => t.id == kPlainTemplateId), isFalse);
    expect(list.length, kMontageTemplates.where((t) => t.id != kPlainTemplateId && t.face == null).length);   // sans le moteur de visage (tout sauf Android), les modèles à filtres de visage ne sont pas proposés
    expect(TemplateStatsApi.usesOf('m:amour'), 90);
    expect(TemplateStatsApi.usesOf('m:inconnu'), 0);
    expect(TemplateStatsApi.rankOf('c:neon'), 2);
    expect(TemplateStatsApi.rankOf('m:fauche'), isNull);
  });

  test('sans aucune utilisation connue : l\'ordre du catalogue, la bande n\'est jamais vide', () {
    final list = popularMontageTemplates();
    expect(list, isNotEmpty);
    // les nouveautés d'abord ; puis les anciens modèles dans l'ordre du catalogue
    expect(list.first.isNew, isTrue);
    final anciens = list.where((t) => !t.isNew).toList();
    expect(anciens.first.id, kMontageTemplates.firstWhere((t) => t.id != kPlainTemplateId && !t.isNew).id);
  });

  test('les modèles « Anniversaire — compte à rebours » et « Événement à venir » posent un compte à rebours à venir et un lieu, valides pour l\'API, 5 widgets au plus', () {
    for (final id in ['anniv_minuteur', 'evenement']) {
      final t = kMontageTemplates.firstWhere((t) => t.id == id);
      final widgets = t.presetWidgets!();
      expect(widgets.length, lessThanOrEqualTo(PostWidgetsLink.max));
      final cd = widgets.firstWhere((w) => w.kind == WidgetKind.countdown);
      expect(DateTime.parse('${cd.config['at']}').isAfter(DateTime.now()), isTrue);   // une échéance dans le futur
      // aucun widget d'office ne bloque la publication : pas de numéro ni de lien obligatoire laissé vide
      expect(widgets.any((w) => w.kind == WidgetKind.whatsapp || w.kind == WidgetKind.call || w.kind == WidgetKind.link), isFalse);
      expect(t.music, isNotNull);   // une musique d'office
    }
  });

  test('la référence du modèle d\'un post et son nombre d\'essais viennent de l\'API ; « m:evenement » est une référence valide', () {
    final p = postFromApi({'id': 'p1', 'author_id': 'u1', 'type': 'post', 'media_kind': 'image', 'media': [], 'counts': {}, 'created_at': '2026-11-09T10:00:00Z', 'studio_template': 'm:evenement', 'template_tries': 7});
    expect(p.studioTemplate, 'm:evenement');
    expect(p.templateTries, 7);
    expect(TemplateRef.parse(p.studioTemplate)?.montage?.name, 'Événement à venir');
    final q = postFromApi({'id': 'p2', 'author_id': 'u1', 'type': 'post', 'media_kind': 'image', 'media': [], 'counts': {}, 'created_at': '2026-11-09T10:00:00Z'});
    expect(q.studioTemplate, isNull);
    expect(q.templateTries, 0);
  });
}
