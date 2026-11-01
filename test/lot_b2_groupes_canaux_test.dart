import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:afrotok/services/api/canaux_mapper.dart';
import 'package:afrotok/services/api/chat_mapper.dart';
import 'package:afrotok/services/api/groups_b2_models.dart';
import 'package:flutter_test/flutter_test.dart';

ApiException _err(int status, String code, [String message = '']) => ApiException(status: status, code: code, message: message);

void main() {
  group('GET /groups/{id}/earnings', () {
    test('total de la part du créateur, entrées et curseur', () {
      final e = GroupEarnings.fromResponse({
        'data': {
          'coins': 140,
          'entries_count': 2,
          'entries': [
            {'id': 'l1', 'coins': 70, 'at': '2026-11-01T08:00:00+00:00', 'buyer': {'id': 'u2', 'username': 'bob', 'avatar_url': 'https://cdn/b.jpg'}},
            {'id': 'l2', 'coins': 70, 'at': '2026-10-01T08:00:00+00:00', 'buyer': {'id': 'u3', 'username': 'cleo', 'avatar_url': ''}},
          ],
        },
        'next_cursor': 'abc',
      });
      expect(e.coins, 140);
      expect(e.entriesCount, 2);
      expect(e.entries.length, 2);
      expect(e.entries.first.buyerName, 'bob');
      expect(e.entries.first.coins, 70);
      expect(e.entries.first.at, isNotNull);
      expect(e.next, 'abc');
    });

    test('groupe gratuit : 0 et liste vide', () {
      final e = GroupEarnings.fromResponse({'data': {'coins': 0, 'entries_count': 0, 'entries': []}, 'next_cursor': null});
      expect(e.coins, 0);
      expect(e.entries, isEmpty);
      expect(e.next, isNull);
    });
  });

  group('GET /admin/groups', () {
    test('lecture d\'une page', () {
      final rows = AdminGroupRow.listFromResponse({
        'data': [
          {
            'id': 'g1', 'name': 'Les amis', 'image_url': '', 'owner': {'id': 'u1', 'username': 'ana', 'avatar_url': ''}, 'is_official': false,
            'is_private': true, 'price_coins': 500, 'member_count': 12, 'is_blocked': true, 'blocked_at': '2026-11-01T08:00:00+00:00',
            'block_reason': 'Contenu interdit', 'created_at': '2026-10-01T08:00:00+00:00',
          },
          {'id': 'g2', 'name': 'Sport', 'owner': {'id': 'u2', 'username': 'bob'}, 'is_blocked': false},
        ],
        'next_cursor': null,
      });
      expect(rows.length, 2);
      expect(rows[0].isBlocked, isTrue);
      expect(rows[0].blockReason, 'Contenu interdit');
      expect(rows[0].priceCoins, 500);
      expect(rows[0].ownerName, 'ana');
      expect(rows[0].blockedAt, isNotNull);
      expect(rows[1].isBlocked, isFalse);
      expect(rows[1].blockReason, '');
    });

    test('messages d\'erreur', () {
      expect(GroupMessages.of(_err(422, 'reason_required')), 'Indique le motif du blocage.');
      expect(GroupMessages.of(_err(423, 'group_blocked')), 'Ce groupe est bloqué par l\'équipe Afrolook.');
      expect(GroupMessages.of(_err(404, 'not_found')), 'Ce groupe n\'est plus disponible.');
      expect(GroupMessages.of(_err(403, 'forbidden')), 'Tu n\'as pas le droit de faire cela.');
      expect(GroupMessages.of(_err(0, 'network')), 'Connexion impossible. Vérifie ta connexion puis réessaie.');
      expect(GroupMessages.of(_err(500, 'x', 'Message du serveur')), 'Message du serveur');
    });
  });

  group('droits fins par membre', () {
    test('lecture des trois booléens, faux par défaut', () {
      final r = GroupMemberRights.fromJson({'can_delete_others': true, 'can_pin': false});
      expect(r.canDeleteOthers, isTrue);
      expect(r.canPin, isFalse);
      expect(r.canInvite, isFalse);
      expect(GroupMemberRights.fromJson(null).canInvite, isFalse);
    });

    test('un membre de l\'API garde ses droits dans l\'ancien format', () {
      final m = memberToLegacy({'user_id': 'u2', 'username': 'bob', 'role': 'member', 'can_write': true, 'can_share': true, 'can_delete_others': true, 'can_pin': false, 'can_invite': true});
      expect(m['can_delete_others'], isTrue);
      expect(m['can_pin'], isFalse);
      expect(m['can_invite'], isTrue);
    });

    test('la fiche d\'un groupe porte mes droits fins et le blocage', () {
      final g = groupToLegacy({
        'id': 'g1', 'name': 'G', 'owner_id': 'u1', 'price_coins': 0, 'is_blocked': true, 'blocked_at': '2026-11-01T08:00:00+00:00', 'block_reason': 'Motif',
        'me': {'role': 'member', 'is_member': true, 'can_write': false, 'can_share': false, 'can_delete_others': true, 'can_pin': true, 'can_invite': false},
      });
      expect(g['me_can_delete_others'], isTrue);
      expect(g['me_can_pin'], isTrue);
      expect(g['me_can_invite'], isFalse);
      expect(g['is_blocked'], isTrue);
      expect(g['block_reason'], 'Motif');
    });
  });

  group('canaux : me dans la liste', () {
    test('administrateur nommé, abonnement en cours', () {
      final c = canalFromApiFull({
        'id': 'c1', 'owner_id': 'u1', 'title': 'Club', 'is_private': true, 'subscription_type': 'monthly', 'price_coins': 300,
        'me': {'is_owner': false, 'is_admin': true, 'is_member': true, 'can_post': true, 'expires_at': '2099-01-01T00:00:00+00:00'},
      }, 'u9');
      expect(c.adminIds, contains('u9'));
      expect(c.usersSuiviId, contains('u9'));
      expect(c.allowedPostersIds, contains('u9'));
      expect(c.monthlySubscriptions!['u9'], isNotNull);
    });

    test('administrateur dont l\'abonnement est échu : n\'est plus administrateur', () {
      final c = canalFromApiFull({
        'id': 'c1', 'owner_id': 'u1', 'title': 'Club', 'is_private': true, 'subscription_type': 'monthly', 'price_coins': 300,
        'me': {'is_owner': false, 'is_admin': false, 'is_member': false, 'can_post': false, 'expires_at': '2020-01-01T00:00:00+00:00'},
      }, 'u9');
      expect(c.adminIds, isNot(contains('u9')));
      expect(c.usersSuiviId, isNot(contains('u9')));
    });

    test('propriétaire : administrateur d\'office', () {
      final c = canalFromApiFull({
        'id': 'c1', 'owner_id': 'u1', 'title': 'Mon canal', 'is_private': false, 'subscription_type': 'free',
        'me': {'is_owner': true, 'is_admin': true, 'is_member': true, 'can_post': true, 'expires_at': null},
      }, 'u1');
      expect(c.adminIds, contains('u1'));
    });
  });
}
