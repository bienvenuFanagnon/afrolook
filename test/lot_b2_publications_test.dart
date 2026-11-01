import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:afrotok/l10n/tr.dart';
import 'package:afrotok/services/api/chat_mapper.dart';
import 'package:afrotok/services/api/notification_text.dart';
import 'package:afrotok/services/api/post_mapper.dart';
import 'package:afrotok/services/api/post_social_models.dart';
import 'package:flutter_test/flutter_test.dart';

ApiException _err(int status, String code, [String message = '']) => ApiException(status: status, code: code, message: message);

void main() {
  tearDown(() => trCurrentLanguage = 'fr');

  group('POST /posts/{id}/repost', () {
    test('première republication (201) : compteurs du serveur', () {
      final r = RepostResult.fromResponse({'data': {'ok': true, 'already': false, 'reposts_count': 4, 'shares_count': 9}});
      expect(r.already, isFalse);
      expect(r.repostsCount, 4);
      expect(r.sharesCount, 9);
    });

    test('republication déjà faite (200) : already vrai', () {
      final r = RepostResult.fromResponse({'data': {'ok': true, 'already': true, 'reposts_count': 1, 'shares_count': 1}});
      expect(r.already, isTrue);
    });

    test('réponse vide : zéros, jamais d\'erreur', () {
      final r = RepostResult.fromResponse({'data': {}});
      expect(r.already, isFalse);
      expect(r.repostsCount, 0);
      expect(r.sharesCount, 0);
    });

    test('codes d\'erreur : un message français pour chacun, le serveur pour un code inconnu', () {
      expect(PostSocialMessages.repost(_err(422, 'cannot_repost_own')), 'Tu ne peux pas republier ta propre publication.');
      expect(PostSocialMessages.repost(_err(422, 'not_repostable')), 'Cette publication ne peut pas être republiée.');
      expect(PostSocialMessages.repost(_err(403, 'blocked')), 'Tu ne peux pas republier cette publication.');
      expect(PostSocialMessages.repost(_err(404, 'not_found')), 'Cette publication n\'est plus disponible.');
      expect(PostSocialMessages.repost(_err(500, 'autre', 'Message du serveur')), 'Message du serveur');
      expect(PostSocialMessages.repost(_err(0, 'network')), 'Connexion impossible. Vérifie ta connexion puis réessaie.');
      expect(PostSocialMessages.repost(StateError('x')), 'Impossible de republier pour le moment. Réessaie.');
    });

    test('les messages suivent la langue de l\'application', () {
      trCurrentLanguage = 'en';
      expect(PostSocialMessages.repost(_err(422, 'cannot_repost_own')), 'You can\'t repost your own post.');
      trCurrentLanguage = 'sw';
      expect(PostSocialMessages.repost(_err(422, 'cannot_repost_own')), isNot('Tu ne peux pas republier ta propre publication.'));
    });
  });

  group('POST /posts/{id}/support-ad', () {
    test('201 : une pièce gagnée par le créateur et le nombre de soutiens', () {
      final r = AdSupportResult.fromResponse({'data': {'ok': true, 'coins': 1, 'ad_support_count': 12}});
      expect(r.coins, 1);
      expect(r.adSupportCount, 12);
    });

    test('409 ad_not_watched, 409 already_supported_today, 422 cannot_support_own', () {
      expect(PostSocialMessages.support(_err(409, 'ad_not_watched')), 'La publicité n\'a pas pu être vérifiée. Regarde-la en entier puis réessaie.');
      expect(PostSocialMessages.support(_err(409, 'already_supported_today')), 'Tu as déjà soutenu cette publication aujourd\'hui. Reviens demain !');
      expect(PostSocialMessages.support(_err(422, 'cannot_support_own')), 'Tu ne peux pas soutenir ta propre publication.');
      expect(PostSocialMessages.support(_err(422, 'not_supportable')), 'Cette publication ne peut pas être soutenue.');
    });

    test('« Réessayer » seulement quand un nouvel essai peut réussir', () {
      expect(PostSocialMessages.supportRetryable(_err(409, 'ad_not_watched')), isTrue);
      expect(PostSocialMessages.supportRetryable(_err(0, 'network')), isTrue);
      expect(PostSocialMessages.supportRetryable(_err(409, 'already_supported_today')), isFalse);
      expect(PostSocialMessages.supportRetryable(_err(422, 'cannot_support_own')), isFalse);
      expect(PostSocialMessages.supportRetryable(_err(422, 'not_supportable')), isFalse);
      expect(PostSocialMessages.supportRetryable(_err(404, 'not_found')), isFalse);
    });
  });

  group('reposted_by dans le fil des abonnements', () {
    test('lecture du bloc', () {
      final by = RepostedBy.fromJson({'id': 'u7', 'username': 'zed', 'avatar_url': 'https://cdn/z.jpg', 'reposted_at': '2026-11-01T08:00:00+00:00'});
      expect(by, isNotNull);
      expect(by!.id, 'u7');
      expect(by.username, 'zed');
      expect(by.repostedAt, isNotNull);
    });

    test('bloc absent ou sans identifiant : null', () {
      expect(RepostedBy.fromJson(null), isNull);
      expect(RepostedBy.fromJson({'username': 'x'}), isNull);
    });

    test('postFromApi remplit le bandeau « a republié » et les compteurs', () {
      final post = postFromApi({
        'id': 'p1',
        'author': {'id': 'u1', 'username': 'ana', 'avatar_url': ''},
        'counts': {'likes': 2, 'comments': 1, 'shares': 3, 'reposts': 2, 'ad_support': 5, 'views': 10},
        'reposted_by': {'id': 'u7', 'username': 'zed', 'avatar_url': 'https://cdn/z.jpg', 'reposted_at': '2026-11-01T08:00:00+00:00'},
        'created_at': '2025-01-01T00:00:00+00:00',
      });
      expect(post.isRepost, isTrue);
      expect(post.reposterUserId, 'u7');
      expect(post.reposterPseudo, 'zed');
      expect(post.reposterImageUrl, 'https://cdn/z.jpg');
      expect(post.users_republier_id?.length, 2);
      expect(post.adSupportCount, 5);
      expect(post.partage, 3);
    });

    test('une publication ordinaire n\'est pas marquée comme republiée', () {
      final post = postFromApi({
        'id': 'p2',
        'author': {'id': 'u1', 'username': 'ana'},
        'counts': {'reposts': 0},
        'created_at': '2026-10-01T00:00:00+00:00',
      });
      expect(post.isRepost, isNot(true));
      expect(post.reposterPseudo, isNull);
      expect(post.users_republier_id, isEmpty);
    });
  });

  group('notifications MENTION, COMMENT_LIKE, REPOST, SUPPORT, FOLLOW_CANAL', () {
    test('notificationFromApi : canal pour FOLLOW_CANAL, publication pour les autres', () {
      final canal = notificationFromApi({
        'id': 'n1', 'type': 'FOLLOW_CANAL', 'title': 'zed', 'body': 'Mon canal', 'actor_id': 'u7', 'subject_type': 'channel', 'subject_id': 'c9',
        'is_read': false, 'created_at': '2026-11-01T08:00:00+00:00',
        'actor': {'id': 'u7', 'username': 'zed', 'display_name': 'Zed Zed', 'avatar_url': 'https://cdn/z.jpg'},
      });
      expect(canal.type, 'FOLLOW_CANAL');
      expect(canal.canal_id, 'c9');
      expect(canal.post_id, anyOf(isNull, isEmpty));
      expect(canal.userData?.pseudo, 'zed');

      final mention = notificationFromApi({
        'id': 'n2', 'type': 'MENTION', 'title': 'zed', 'body': 'salut @ana', 'actor_id': 'u7', 'subject_type': 'post', 'subject_id': 'p1',
        'is_read': true, 'created_at': '2026-11-01T08:00:00+00:00',
      });
      expect(mention.post_id, 'p1');
      expect(mention.canal_id, anyOf(isNull, isEmpty));
      expect(mention.is_open, isTrue);
    });

    test('phrases en français pour chaque nouveau type', () {
      expect(NotificationText.sentence('MENTION', body: 'salut @ana'), 'vous a mentionné : « salut @ana »');
      expect(NotificationText.sentence('MENTION'), 'vous a mentionné');
      expect(NotificationText.sentence('COMMENT_LIKE'), 'a aimé votre commentaire');
      expect(NotificationText.sentence('REPOST'), 'a republié votre publication');
      expect(NotificationText.sentence('SUPPORT'), 'vous a soutenu en regardant une pub : +1 pièce');
      expect(NotificationText.sentence('FOLLOW_CANAL', body: 'Mon canal'), 'suit votre canal « Mon canal »');
      expect(NotificationText.sentence('COMMENT', body: 'texte'), isNull);
    });

    test('phrases traduites dans les huit langues (jamais le français)', () {
      for (final lang in ['en', 'es', 'de', 'ar', 'pt', 'zh', 'sw']) {
        trCurrentLanguage = lang;
        for (final t in NotificationText.newTypes) {
          final s = NotificationText.sentence(t)!;
          expect(s, isNot(NotificationText.sentence('XX') ?? ''), reason: '$t / $lang');
          trCurrentLanguage = 'fr';
          final fr = NotificationText.sentence(t)!;
          trCurrentLanguage = lang;
          expect(s, isNot(fr), reason: '$t / $lang n\'est pas traduit');
        }
      }
    });

    test('chaque nouveau type est dans un groupe de filtre, avec icône et libellé', () {
      final filed = NotificationText.groupTypes.values.expand((e) => e).toSet();
      for (final t in NotificationText.newTypes) {
        expect(filed, contains(t), reason: t);
        expect(NotificationText.look(t), isNotNull, reason: t);
        expect(NotificationText.typeLabel(t), isNot(t), reason: t);
      }
    });
  });
}
