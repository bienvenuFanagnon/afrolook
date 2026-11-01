import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:afrotok/l10n/tr.dart';
import 'package:afrotok/l10n/tr_restes.dart';
import 'package:afrotok/services/api/chat_mapper.dart';
import 'package:afrotok/services/api/learning_admin_api.dart';
import 'package:afrotok/services/api/live_trial.dart';
import 'package:afrotok/services/api/notification_text.dart';
import 'package:afrotok/services/api/publications_api.dart';
import 'package:afrotok/services/api/services_api.dart';
import 'package:afrotok/services/quiz/quiz_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lecture des réponses ajoutées par l'API le 01/11/2026 (lot « restes ») : services, essai d'un live payant, quiz, contes, notifications.
void main() {
  group('Services des utilisateurs', () {
    final json = <String, dynamic>{
      'id': '01HSERVICE',
      'owner_id': 'u1',
      'user': {'id': 'u1', 'username': 'ama', 'avatar_url': 'https://cdn/a.jpg'},
      'title': 'Plombier',
      'description': 'Réparations à domicile',
      'category': 'Plomberie',
      'country': 'Togo',
      'city': 'Lomé',
      'contact': '+22890000000',
      'image_url': 'https://cdn/s.jpg',
      'is_available': true,
      'views_count': 12,
      'likes_count': 3,
      'contacts_count': 2,
      'shares_count': 1,
      'liked_by_me': true,
      'is_mine': false,
      // noms de l'ancien document
      'userId': 'u1',
      'titre': 'Plombier',
      'disponible': true,
      'imageCourverture': 'https://cdn/s.jpg',
      'vues': 12,
      'like': 3,
      'contactWhatsapp': 2,
      'partage': 1,
      'usersLikeId': ['me'],
      'createdAt': 1790000000000,
      'updatedAt': 1790000100000,
    };

    test('un service de l\'API est lu sans adaptation (noms de l\'ancien document)', () {
      final s = PubApi.serviceFromApi(json);
      expect(s.id, '01HSERVICE');
      expect(s.titre, 'Plombier');
      expect(s.category, 'Plomberie');
      expect(s.city, 'Lomé');
      expect(s.imageCourverture, 'https://cdn/s.jpg');
      expect(s.vues, 12);
      expect(s.like, 3);
      expect(s.contactWhatsapp, 2);
      expect(s.partage, 1);
      expect(s.usersLikeId, ['me']);
      expect(s.disponible, isTrue);
      expect(s.user?.pseudo, 'ama');
    });

    test('corps envoyé : seulement les champs utiles, avec cover_upload_id', () {
      final s = PubApi.serviceFromApi(json)..titre = '  Électricien ';
      final b = ServicesApi.body(s, coverUploadId: '01HUPLOAD');
      expect(b['title'], 'Électricien');
      expect(b['cover_upload_id'], '01HUPLOAD');
      expect(b['is_available'], true);
      expect(b['contact'], '+22890000000');
      for (final ignored in ['vues', 'like', 'userId', 'imageCourverture', 'createdAt', 'id']) {
        expect(b.containsKey(ignored), isFalse, reason: ignored);
      }
      expect(ServicesApi.body(s).containsKey('cover_upload_id'), isFalse);
    });

    test('j\'aime : total et état', () {
      final yes = ServiceLikeResult.fromJson({'like': 4, 'liked': true}, fallbackLiked: false);
      expect(yes.like, 4);
      expect(yes.liked, isTrue);
      final no = ServiceLikeResult.fromJson({'like': 3, 'liked': false}, fallbackLiked: true);
      expect(no.liked, isFalse);
      expect(ServiceLikeResult.fromJson({'like': 5}, fallbackLiked: true).liked, isTrue);
    });

    test('merge : les compteurs du serveur remplacent ceux de l\'écran', () {
      final shown = PubApi.serviceFromApi(json);
      final fresh = PubApi.serviceFromApi({...json, 'vues': 13, 'like': 9, 'partage': 4, 'usersLikeId': <String>[]});
      ServicesApi.merge(shown, fresh);
      expect(shown.vues, 13);
      expect(shown.like, 9);
      expect(shown.partage, 4);
      expect(shown.usersLikeId, isEmpty);
    });

    test('message d\'erreur en français', () {
      expect(ServicesApi.message(ApiException(status: 0, code: 'network', message: '')), contains('Connexion impossible'));
      expect(ServicesApi.message(ApiException(status: 422, code: 'upload_invalid', message: 'Image absente.')), 'Image absente.');
      expect(ServicesApi.message(Exception('x'), fallback: 'Oups'), 'Oups');
    });
  });

  group('Essai gratuit d\'un live payant', () {
    test('GET /lives/{id} : data.me.trial avant le premier jeton', () {
      final t = LiveTrial.fromLive({
        'me': {
          'has_entry': false,
          'trial': {'minutes': 2, 'started_at': null, 'ends_at': null, 'seconds_left': 120, 'expired': false},
        },
      });
      expect(t, isNotNull);
      expect(t!.minutes, 2);
      expect(t.secondsLeft, 120);
      expect(t.startedAt, isNull);
      expect(t.expired, isFalse);
    });

    test('POST /lives/{id}/token : data.trial pendant l\'essai', () {
      final t = LiveTrial.fromLive({
        'token': 'abc',
        'trial': {'minutes': 2, 'started_at': '2026-11-01T10:00:00+00:00', 'ends_at': '2026-11-01T10:02:00+00:00', 'seconds_left': 95, 'expired': false},
      });
      expect(t!.secondsLeft, 95);
      expect(t.startedAt, isNotNull);
      expect(t.endsAt!.difference(t.startedAt!).inSeconds, 120);
    });

    test('402 entry_required : details.trial, essai fini', () {
      final e = ApiException(status: 402, code: 'entry_required', message: 'Entrée à payer.', details: {
        'coins': 50,
        'trial': {'minutes': 2, 'started_at': '2026-11-01T10:00:00+00:00', 'ends_at': '2026-11-01T10:02:00+00:00', 'seconds_left': 0, 'expired': true},
      });
      final t = LiveTrial.fromJson(e.details['trial']);
      expect(t!.expired, isTrue);
      expect(t.secondsLeft, 0);
      expect(e.coins, 50);
    });

    test('trial null (hôte, entrée payée, live gratuit) ou absent : aucun essai', () {
      expect(LiveTrial.fromLive({'me': {'trial': null}}), isNull);
      expect(LiveTrial.fromLive({'me': {'has_entry': true}}), isNull);
      expect(LiveTrial.fromJson(null), isNull);
      expect(LiveTrial.fromJson('x'), isNull);
    });

    test('secondes négatives ramenées à 0', () {
      expect(LiveTrial.fromJson({'minutes': 1, 'seconds_left': -3, 'expired': false})!.secondsLeft, 0);
    });
  });

  group('Quiz : challengeAdsRequired', () {
    test('absent = pub exigée (valeur par défaut)', () {
      expect(QuizConfig.fromMap({'enabled': true}).challengeAdsRequired, isTrue);
      expect(const QuizConfig().challengeAdsRequired, isTrue);
    });
    test('faux = pas de pub', () {
      expect(QuizConfig.fromMap({'challengeAdsRequired': false}).challengeAdsRequired, isFalse);
    });
    test('vrai = pub exigée', () {
      expect(QuizConfig.fromMap({'challengeAdsRequired': true}).challengeAdsRequired, isTrue);
    });
  });

  group('Contes : administration', () {
    test('liste des contes (actifs et masqués)', () {
      final list = LearningAdminApi.parseStories({
        'data': [
          {'id': 's1', 'title': 'Le lièvre', 'collection_id': 'c1', 'active': true, 'featured': true, 'price': 30, 'minutes': 6, 'kind': 'court'},
          {'id': 's2', 'title': 'Anansi', 'collection_id': 'c1', 'active': false, 'featured': false, 'price': null, 'minutes': null, 'kind': null},
        ],
      });
      expect(list, hasLength(2));
      expect(list[0].active, isTrue);
      expect(list[0].featured, isTrue);
      expect(list[0].price, 30);
      expect(list[0].minutes, 6);
      expect(list[1].active, isFalse);
      expect(list[1].price, isNull);
      expect(list[1].minutes, isNull);
      expect(list[1].collectionId, 'c1');
      expect(list.where((c) => !c.active).map((c) => c.id), ['s2']);
    });

    test('config est un objet (ou, avant, une liste vide)', () {
      final base = {'readers': 3, 'week': {'opens': 1}, 'per_day': [], 'catalog': {'stories': 3, 'active': 2}};
      expect(LearningAdminApi.parseContesOverview({...base, 'config': <String, dynamic>{}})['config'], <String, dynamic>{});
      expect(LearningAdminApi.parseContesOverview({...base, 'config': []})['config'], <String, dynamic>{});
      expect(LearningAdminApi.parseContesOverview({...base, 'config': {'priceCourt': 12}})['config'], {'priceCourt': 12});
    });
  });

  group('Notifications SERVICE, BOOST_SOUMIS, CANAL_ADMIN', () {
    test('phrases en français', () {
      trCurrentLanguage = 'fr';
      expect(NotificationText.sentence('SERVICE', body: 'Plombier'), 's\'intéresse à votre service « Plombier »');
      expect(NotificationText.sentence('SERVICE'), 's\'intéresse à votre service');
      expect(NotificationText.sentence('BOOST_SOUMIS', body: 'Publication : Mon post — 2 semaines'), 'a soumis un boost à valider : Publication : Mon post — 2 semaines');
      expect(NotificationText.sentence('CANAL_ADMIN', body: 'Mon canal'), 'vous a nommé administrateur de son canal « Mon canal »');
    });

    test('rangées dans un groupe, avec icône et libellé traduit', () {
      final filed = NotificationText.groupTypes.values.expand((e) => e).toSet();
      for (final t in ['SERVICE', 'BOOST_SOUMIS', 'CANAL_ADMIN']) {
        expect(filed, contains(t));
        expect(NotificationText.look(t), isNotNull);
        expect(NotificationText.newTypes, contains(t));
      }
      trCurrentLanguage = 'en';
      expect(NotificationText.typeLabel('BOOST_SOUMIS'), 'Boosts to review');
      expect(NotificationText.typeLabel('SERVICE'), 'Service interest');
      trCurrentLanguage = 'fr';
    });

    test('sujets : service et annonce -> post_id, canal -> canal_id', () {
      final base = {'actor_id': 'u1', 'is_read': false, 'created_at': '2026-11-01T08:00:00+00:00', 'title': 'zed'};
      final service = notificationFromApi({...base, 'id': 'n1', 'type': 'SERVICE', 'subject_type': 'service', 'subject_id': 'sv1', 'body': 'Plombier'});
      expect(service.post_id, 'sv1');
      final boost = notificationFromApi({...base, 'id': 'n2', 'type': 'BOOST_SOUMIS', 'subject_type': 'ad', 'subject_id': 'ad9', 'body': 'Publication : x — 1 semaine'});
      expect(boost.post_id, 'ad9');
      final admin = notificationFromApi({...base, 'id': 'n3', 'type': 'CANAL_ADMIN', 'subject_type': 'channel', 'subject_id': 'c4', 'body': 'Mon canal'});
      expect(admin.canal_id, 'c4');
      expect(admin.post_id, anyOf(isNull, isEmpty));
    });
  });

  group('Groupes : owner_plan', () {
    test('gold, premium, free passent ; absent reste null', () {
      expect(groupToLegacy({'id': 'g1', 'owner_plan': 'gold'})['owner_plan'], 'gold');
      expect(groupToLegacy({'id': 'g1', 'owner_plan': 'gold'})['owner_is_gold'], isTrue);
      expect(groupToLegacy({'id': 'g1', 'owner_plan': 'premium'})['owner_plan'], 'premium');
      expect(groupToLegacy({'id': 'g1', 'owner_plan': 'free'})['owner_plan'], 'free');
      expect(groupToLegacy({'id': 'g1', 'owner_plan': 'free'})['owner_is_gold'], isFalse);
      expect(groupToLegacy({'id': 'g1'})['owner_plan'], isNull);
      expect(groupToLegacy({'id': 'g1', 'owner_plan': 'autre'})['owner_plan'], isNull);
    });
  });

  group('Traductions du lot « restes »', () {
    const langs = ['en', 'es', 'de', 'ar', 'pt', 'zh', 'sw'];

    test('chaque texte a les sept langues, non vides, avec les mêmes variables', () {
      final vars = RegExp(r'\{[a-z]+\}');
      kTrRestes.forEach((fr, entry) {
        for (final l in langs) {
          expect(entry[l], isNotNull, reason: '$fr / $l manquant');
          expect(entry[l]!.trim(), isNotEmpty, reason: '$fr / $l vide');
          expect(vars.allMatches(entry[l]!).map((m) => m.group(0)).toSet(), vars.allMatches(fr).map((m) => m.group(0)).toSet(), reason: 'variables de "$fr" / $l');
        }
      });
    });

    test('trFor remplace les variables dans chaque langue', () {
      for (final l in langs) {
        final s = trFor(l, 'Filtre actif : {p}', {'p': 'Togo'});
        expect(s, contains('Togo'), reason: l);
        expect(s, isNot(contains('{p}')), reason: l);
        expect(s, isNot('Filtre actif : Togo'), reason: '$l n\'est pas traduit');
      }
      expect(trFor('fr', 'Filtre actif : {p}', {'p': 'Togo'}), 'Filtre actif : Togo');
    });
  });
}
