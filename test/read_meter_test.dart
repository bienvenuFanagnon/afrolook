import 'package:afrotok/services/read_meter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    ReadMeter.enabled = true;
    ReadMeter.instance.session.clear();
  });

  test('les lectures s\'additionnent par source', () {
    ReadMeter.add('feed_repository.dart:129', 30);
    ReadMeter.add('feed_repository.dart:129', 12);
    ReadMeter.add('homeScreen.dart:368', 5);
    expect(ReadMeter.instance.session['feed_repository.dart:129'], 42);
    expect(ReadMeter.instance.session['homeScreen.dart:368'], 5);
  });

  test('rien n\'est compté quand le compteur est coupé ou quand le nombre est nul', () {
    ReadMeter.add('a.dart:1', 0);
    ReadMeter.add('a.dart:1', -3);
    expect(ReadMeter.instance.session.containsKey('a.dart:1'), isFalse);
    ReadMeter.enabled = false;
    ReadMeter.add('b.dart:2', 10);
    expect(ReadMeter.instance.session.containsKey('b.dart:2'), isFalse);
  });

  test('l\'envoi garde les sources les plus actives, de la plus lue à la moins lue', () {
    final all = {for (var i = 1; i <= 100; i++) 'f$i.dart:1': i};
    final top = ReadMeter.top(all);
    expect(top.length, ReadMeter.maxTagsPerReport);
    expect(top.keys.first, 'f100.dart:1');
    expect(top.containsKey('f41.dart:1'), isTrue); // 100 → 41 : 60 sources
    expect(top.containsKey('f40.dart:1'), isFalse);
  });
}
