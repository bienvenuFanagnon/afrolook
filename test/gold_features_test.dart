import 'package:afrotok/ads/rewards_service.dart';
import 'package:afrotok/services/face_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fonctions du Studio à débloquer : les 13 clés du serveur (le mixage des volumes est gratuit), sans doublon, chacune avec un libellé', () {
    const serveur = {
      'looks_pro', 'face_deform', 'money_gestures', 'time_effects', //
      'avatars', 'bg_blur', 'hair_color', 'timed_message',
      'bg_virtual', 'cloth_color', 'pin_video', 'commerce_card', 'hand_gestures',
    };
    final cles = RewardsService.featureCatalog.map((f) => f.$1).toList();
    expect(cles.toSet(), serveur);
    expect(cles.length, cles.toSet().length);
    for (final f in RewardsService.featureCatalog) {
      expect(f.$2.trim(), isNotEmpty);
      expect(RewardsService.featureLabel(f.$1), f.$2);
    }
  });

  test('offres dynamiques : export et fonctions connus, fonction inconnue refusée, plus de Premium, pièces ni « sans pub »', () {
    expect(RewardsService.dynamicOffer('export'), isNotNull);
    expect(RewardsService.dynamicOffer('feature:avatars')?.cap, 1);
    expect(RewardsService.dynamicOffer('feature:nimporte'), isNull);
    expect(RewardsService.dynamicOffer('gold_pass'), isNull); // sans état du serveur : pas de prochaine passe connue
    final ids = RewardsService.offers.map((o) => o.id).toSet();
    expect(ids, {'flame_shield', 'stickers_3', 'photos_3', 'card_capture'});
    expect(RewardsService.exportAds, 3); // valeur de départ tant que le serveur n'a pas répondu
    expect(RewardsService.goldPriceMonth, 500);
  });

  test('groupe « Visage » : les deux premiers effets (Elfe, Lapin) sont gratuits, les autres restent à débloquer', () {
    expect(FaceEngine.freePresets, 2);
    expect(FaceEngine.presets.length, greaterThan(FaceEngine.freePresets));
    expect(FaceEngine.presets.take(2).map((p) => p.label), ['Elfe', 'Lapin']);
  });
}
