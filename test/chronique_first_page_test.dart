import 'package:afrotok/services/chronique_first_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> raw(String id, {Duration? expiresIn}) => {
      'id': id,
      'type': 'text',
      'text': 'Bonjour $id',
      'author': {'id': 'u$id', 'username': 'Auteur $id'},
      'created_at': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
      'expires_at': DateTime.now().add(expiresIn ?? const Duration(hours: 10)).toIso8601String(),
    };

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ChroniqueFirstPage.resetForTest();
  });

  test('la dernière première page enregistrée s\'affiche tout de suite à la réouverture (sans serveur)', () async {
    await ChroniqueFirstPage.persistRaw('me', [raw('a'), raw('b')], 'curseur2');
    ChroniqueFirstPage.resetForTest();   // nouvelle ouverture de l'application
    expect(ChroniqueFirstPage.stale(), isNull);

    await ChroniqueFirstPage.ensureLoaded('me');
    final s = ChroniqueFirstPage.stale();
    expect(s, isNotNull);
    expect(s!.items.map((c) => c.id), ['a', 'b']);
    expect(s.last, 'curseur2');
    expect(s.hasMore, isTrue);
  });

  test('les chroniques expirées ne sont jamais montrées, et rien n\'est montré si tout a expiré', () async {
    await ChroniqueFirstPage.persistRaw('me', [raw('vivante'), raw('morte', expiresIn: const Duration(seconds: -5))], null);
    ChroniqueFirstPage.resetForTest();
    await ChroniqueFirstPage.ensureLoaded('me');
    expect(ChroniqueFirstPage.stale()!.items.map((c) => c.id), ['vivante']);

    SharedPreferences.setMockInitialValues({});
    ChroniqueFirstPage.resetForTest();
    await ChroniqueFirstPage.persistRaw('me', [raw('morte', expiresIn: const Duration(seconds: -5))], null);
    ChroniqueFirstPage.resetForTest();
    await ChroniqueFirstPage.ensureLoaded('me');
    expect(ChroniqueFirstPage.stale(), isNull);
  });

  test('chaque compte a sa page ; sans compte, rien n\'est lu ni écrit', () async {
    await ChroniqueFirstPage.persistRaw('ann', [raw('a')], null);
    await ChroniqueFirstPage.persistRaw(null, [raw('x')], null);
    ChroniqueFirstPage.resetForTest();
    await ChroniqueFirstPage.ensureLoaded('bob');
    expect(ChroniqueFirstPage.stale(), isNull);
    ChroniqueFirstPage.resetForTest();
    await ChroniqueFirstPage.ensureLoaded('ann');
    expect(ChroniqueFirstPage.stale()!.items.single.id, 'a');
  });

  test('une page lue par le serveur n\'est pas écrasée par la page enregistrée, et fresh() n\'est vrai que 2 minutes', () async {
    await ChroniqueFirstPage.persistRaw('me', [raw('ancienne')], null);
    ChroniqueFirstPage.resetForTest();
    ChroniqueFirstPage.save([(await _one('nouvelle'))], null, hasMore: false);
    await ChroniqueFirstPage.ensureLoaded('me');
    expect(ChroniqueFirstPage.stale()!.items.single.id, 'nouvelle');
    expect(ChroniqueFirstPage.fresh(), isNotNull);
  });
}

Future<dynamic> _one(String id) async {
  await ChroniqueFirstPage.persistRaw('tmp', [raw(id)], null);
  ChroniqueFirstPage.resetForTest();
  await ChroniqueFirstPage.ensureLoaded('tmp');
  final c = ChroniqueFirstPage.stale()!.items.single;
  ChroniqueFirstPage.resetForTest();
  return c;
}
