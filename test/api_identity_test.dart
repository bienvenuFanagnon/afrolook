import 'package:afrotok/services/api/api_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String? fbUid;

  setUp(() {
    fbUid = 'uid-firebase-A';
    ApiIdentity.firebaseUid = () => fbUid;
    ApiIdentity.clear();
  });

  test('avant le premier chargement : repli sur l\'uid Firebase', () {
    expect(ApiIdentity.myId, 'uid-firebase-A');
  });

  test('après /bootstrap : l\'identifiant de l\'API (ULID) remplace l\'uid Firebase', () {
    ApiIdentity.set('01hzx0000000000000000000ab');
    expect(ApiIdentity.myId, '01hzx0000000000000000000ab');
  });

  test('un identifiant vide ou nul ne remplace jamais le précédent', () {
    ApiIdentity.set('01hzx0000000000000000000ab');
    ApiIdentity.set(null);
    ApiIdentity.set('');
    expect(ApiIdentity.myId, '01hzx0000000000000000000ab');
  });

  test('un autre compte Firebase connecté ensuite ne reçoit jamais l\'ancien identifiant API', () {
    ApiIdentity.set('01hzx0000000000000000000ab');
    fbUid = 'uid-firebase-B';
    expect(ApiIdentity.myId, 'uid-firebase-B');
    // le nouveau compte charge son /bootstrap
    ApiIdentity.set('01hzx0000000000000000000cd');
    expect(ApiIdentity.myId, '01hzx0000000000000000000cd');
  });

  test('clear() à la déconnexion', () {
    ApiIdentity.set('01hzx0000000000000000000ab');
    ApiIdentity.clear();
    expect(ApiIdentity.myId, 'uid-firebase-A');
    fbUid = null;
    expect(ApiIdentity.myId, isNull);
  });
}
