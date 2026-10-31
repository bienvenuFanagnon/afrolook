import 'package:afrotok/services/crypto/key_change_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late KeyChangeTracker t;
  setUp(() => t = KeyChangeTracker(MemoryKeyValueStore()));

  test('première vue retenue, même clé : aucun avertissement', () async {
    expect(await t.observe('moi', 'ami', 'CLE_A', 1), KeyCheck.firstSeen);
    expect(await t.observe('moi', 'ami', 'CLE_A', 1), KeyCheck.unchanged);
    expect(await t.hasWarning('moi', 'ami'), isFalse);
  });

  test('clé différente : avertissement qui persiste jusqu\'à acquittement', () async {
    await t.observe('moi', 'ami', 'CLE_A', 1);
    expect(await t.observe('moi', 'ami', 'CLE_B', 2), KeyCheck.changed);
    expect(await t.hasWarning('moi', 'ami'), isTrue);
    expect(await t.observe('moi', 'ami', 'CLE_B', 2), KeyCheck.changed, reason: 'toujours signalé tant que non acquitté');
    expect(await t.warningsAmong('moi', ['ami', 'autre']), ['ami']);

    await t.acknowledge('moi', 'ami');
    expect(await t.hasWarning('moi', 'ami'), isFalse);
    expect(await t.observe('moi', 'ami', 'CLE_B', 2), KeyCheck.unchanged);
    // un nouveau changement après acquittement avertit de nouveau
    expect(await t.observe('moi', 'ami', 'CLE_C', 3), KeyCheck.changed);
  });

  test('chaque personne connectée a son propre registre ; sa propre clé n\'est jamais signalée', () async {
    await t.observe('moi', 'ami', 'CLE_A', 1);
    expect(await t.observe('toi', 'ami', 'CLE_B', 1), KeyCheck.firstSeen);
    expect(await t.observe('moi', 'moi', 'X', 1), KeyCheck.unchanged);
  });
}
