import 'dart:convert';
import 'dart:typed_data';

import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.replies);
  final List<(int, Object?)> replies;
  final List<RequestOptions> seen = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    seen.add(options);
    final (status, body) = replies[seen.length <= replies.length ? seen.length - 1 : replies.length - 1];
    return ResponseBody.fromString(jsonEncode(body), status, headers: {'content-type': ['application/json']});
  }

  @override
  void close({bool force = false}) {}
}

ApiClient make(FakeAdapter a) {
  var n = 0;
  return ApiClient(
    baseUrl: 'https://api.test/v1',
    token: ({bool forceRefresh = false}) async => forceRefresh ? 'frais' : 't${n++}',
    appCheck: () async => 'ac',
    retryBase: Duration.zero,
    dio: Dio()..httpClientAdapter = a,
  );
}

void main() {
  test('envoie jeton et App Check, renvoie data', () async {
    final a = FakeAdapter([(200, {'data': {'ok': 1}})]);
    final r = ApiClient.data(await make(a).get('/x'));
    expect(r, {'ok': 1});
    expect(a.seen.first.headers['Authorization'], startsWith('Bearer '));
    expect(a.seen.first.headers['X-Firebase-AppCheck'], 'ac');
  });

  test('401 : un seul nouvel essai avec jeton rafraîchi', () async {
    final a = FakeAdapter([(401, {'code': 'unauthenticated', 'message': 'x', 'details': {}}), (200, {'data': 1})]);
    await make(a).get('/x');
    expect(a.seen.length, 2);
    expect(a.seen[1].headers['Authorization'], 'Bearer frais');
  });

  test('lecture : réessaie après 503 puis réussit', () async {
    final a = FakeAdapter([(503, {}), (503, {}), (200, {'data': 1})]);
    await make(a).get('/x');
    expect(a.seen.length, 3);
  });

  test('écriture sans clé : jamais réessayée', () async {
    final a = FakeAdapter([(503, {}), (200, {'data': 1})]);
    await expectLater(make(a).post('/x', body: {}), throwsA(isA<ApiException>()));
    expect(a.seen.length, 1);
  });

  test('paiement : la même clé d idempotence est renvoyée à chaque tentative', () async {
    final a = FakeAdapter([(503, {}), (201, {'data': 1})]);
    await make(a).pay('/pay', body: {'coins': 5});
    expect(a.seen.length, 2);
    expect(a.seen[0].headers['Idempotency-Key'], isNotNull);
    expect(a.seen[1].headers['Idempotency-Key'], a.seen[0].headers['Idempotency-Key']);
  });

  test('erreur typée : pièces insuffisantes', () async {
    final a = FakeAdapter([(402, {'code': 'insufficient_coins', 'message': 'Pièces insuffisantes.', 'details': {'coins': 1}})]);
    try {
      await make(a).post('/c', body: {});
      fail('devait échouer');
    } on ApiException catch (e) {
      expect(e.isInsufficientCoins, isTrue);
      expect(e.coins, 1);
      expect(e.message, 'Pièces insuffisantes.');
    }
  });

  test('modules : tout sur l ancien système par défaut', () {
    final m = ApiModules();
    expect(m.useApi('lives'), isFalse);
    m.update({'lives': true});
    expect(m.useApi('lives'), isTrue);
    expect(m.useApi('music'), isFalse);
    m.update({'all': true, 'music': false});
    expect(m.useApi('lives'), isTrue);
    expect(m.useApi('music'), isFalse);
  });
}
