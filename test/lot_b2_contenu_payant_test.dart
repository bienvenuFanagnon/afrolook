import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:afrotok/services/api/paid_content_b2_models.dart';
import 'package:afrotok/services/api/paid_file_types.dart';
import 'package:flutter_test/flutter_test.dart';

ApiException _err(int status, String code, [String message = '']) => ApiException(status: status, code: code, message: message);

Map<String, dynamic> _episode({String id = 'e1', int n = 1, bool free = false, bool access = true, String? reaction}) => {
      'id': id, 'series_id': 's1', 'episode_number': n, 'title': 'Épisode $n', 'description': 'Suite', 'content_type': 'video', 'is_free': free,
      'price_xof': 0, 'duration_sec': 600, 'page_count': 0, 'thumbnail_url': 'https://cdn/t.jpg', 'views_count': 5, 'likes_count': 3,
      'dislikes_count': 1, 'shares_count': 2, 'created_at': '2026-11-01T08:00:00+00:00', 'has_access': access, 'my_reaction': reaction,
    };

void main() {
  group('épisodes de séries', () {
    test('liste classée telle que le serveur la renvoie', () {
      final list = SeriesEpisode.listFromResponse({'data': [_episode(n: 1, free: true), _episode(id: 'e2', n: 2, access: false)]});
      expect(list.map((e) => e.number), [1, 2]);
      expect(list[0].isFree, isTrue);
      expect(list[1].hasAccess, isFalse);
      expect(list[0].views, 5);
      expect(list[0].likes, 3);
      expect(list[0].shares, 2);
      expect(list[0].thumbnailUrl, 'https://cdn/t.jpg');
    });

    test('fiche d\'un épisode avec file_kinds et ma réaction', () {
      final e = SeriesEpisode.fromResponse({'data': {..._episode(reaction: 'like'), 'file_kinds': ['pdf', 'video']}});
      expect(e.fileKinds, ['pdf', 'video']);
      expect(e.myReaction, 'like');
      expect(e.isEbook, isFalse);
    });

    test('un livre est reconnu, le type inconnu devient vidéo', () {
      expect(SeriesEpisode.fromJson({..._episode(), 'content_type': 'ebook'}).isEbook, isTrue);
      expect(SeriesEpisode.fromJson({..._episode(), 'content_type': 'autre'}).isEbook, isFalse);
    });

    test('copyWith : changer ou retirer ma réaction', () {
      final e = SeriesEpisode.fromJson(_episode(reaction: 'like'));
      final dislike = e.copyWith(likes: 2, dislikes: 2, myReaction: 'dislike');
      expect(dislike.myReaction, 'dislike');
      expect(dislike.likes, 2);
      expect(e.copyWith(clearReaction: true).myReaction, isNull);
    });

    test('lien d\'accès signé : adresse et durée (0 pour un ancien fichier)', () {
      final a = EpisodeAccess.fromResponse({'data': {'url': 'https://cdn/signed', 'expires_in': 600}});
      expect(a.url, 'https://cdn/signed');
      expect(a.expiresIn, 600);
      expect(EpisodeAccess.fromResponse({'data': {'url': 'https://cdn/old', 'expires_in': 0}}).expiresIn, 0);
    });

    test('partage : compté une première fois puis non recompté', () {
      final first = ShareCounted.fromResponse({'data': {'ok': true, 'counted': true, 'shares_count': 7}});
      expect(first.counted, isTrue);
      expect(first.sharesCount, 7);
      expect(ShareCounted.fromResponse({'data': {'ok': true, 'counted': false, 'shares_count': 7}}).counted, isFalse);
    });

    test('messages d\'erreur des épisodes', () {
      expect(PaidContentMessages.of(_err(422, 'not_a_series')), 'Ce contenu n\'est pas une série.');
      expect(PaidContentMessages.of(_err(404, 'series_not_found')), 'Cette série n\'existe plus.');
      expect(PaidContentMessages.of(_err(409, 'episode_number_taken')), 'Ce numéro d\'épisode est déjà pris.');
      expect(PaidContentMessages.of(_err(422, 'upload_not_private')), 'Le fichier de l\'épisode doit être envoyé en privé.');
      expect(PaidContentMessages.of(_err(422, 'upload_invalid')), 'Le fichier envoyé n\'est pas valide. Réessaie.');
      expect(PaidContentMessages.of(_err(403, 'not_purchased')), 'Achète cette série pour regarder cet épisode.');
      expect(PaidContentMessages.of(_err(404, 'no_file')), 'Cet épisode n\'a pas encore de fichier.');
      expect(PaidContentMessages.of(_err(403, 'forbidden')), 'Tu n\'as pas le droit de faire cela.');
      expect(PaidContentMessages.of(_err(0, 'network')), 'Connexion impossible. Vérifie ta connexion puis réessaie.');
      expect(PaidContentMessages.of(_err(500, 'x', 'Message du serveur')), 'Message du serveur');
    });
  });

  group('aperçu d\'un code promo', () {
    test('code valide en pourcentage', () {
      final p = PromoPreview.fromResponse({'data': {'valid': true, 'reason': null, 'type': 'percent', 'value': 20, 'price_xof': 5000, 'price_after_xof': 4000}});
      expect(p.valid, isTrue);
      expect(p.type, 'percent');
      expect(p.value, 20);
      expect(p.priceXof, 5000);
      expect(p.priceAfterXof, 4000);
      expect(p.savingXof, 1000);
    });

    test('code invalide : pas une erreur, un motif', () {
      final cases = {
        'unknown': 'Ce code n\'existe pas pour ce contenu.',
        'inactive': 'Ce code n\'est plus actif.',
        'expired': 'Ce code a expiré.',
        'exhausted': 'Ce code a déjà été utilisé le nombre maximum de fois.',
      };
      cases.forEach((reason, text) {
        final p = PromoPreview.fromResponse({'data': {'valid': false, 'reason': reason, 'type': null, 'value': null, 'price_xof': 5000, 'price_after_xof': 5000}});
        expect(p.valid, isFalse);
        expect(p.reason, reason);
        expect(p.value, isNull);
        expect(p.reasonMessage, text);
      });
    });
  });

  group('commentaire modifié', () {
    test('réponse du PATCH', () {
      final c = EditedComment.fromResponse({'data': {'id': 'c1', 'text': 'Nouveau texte', 'edited_at': '2026-11-01T09:00:00+00:00'}});
      expect(c.id, 'c1');
      expect(c.text, 'Nouveau texte');
      expect(c.editedAt, isNotNull);
    });
  });

  group('types de fichiers payants élargis', () {
    test('types privés acceptés par l\'API', () {
      expect(PaidFileTypes.mimeFor('son.WAV'), 'audio/wav');
      expect(PaidFileTypes.mimeFor('/tmp/film.mov'), 'video/quicktime');
      expect(PaidFileTypes.mimeFor('film.webm'), 'video/webm');
      expect(PaidFileTypes.mimeFor('livre.epub'), 'application/epub+zip');
      expect(PaidFileTypes.mimeFor('doc.docx'), contains('wordprocessingml'));
      expect(PaidFileTypes.mimeFor('maquette.psd'), 'image/vnd.adobe.photoshop');
      expect(PaidFileTypes.mimeFor('pack.7z'), 'application/x-7z-compressed');
      expect(PaidFileTypes.mimeFor('pack.rar'), 'application/vnd.rar');
      expect(PaidFileTypes.mimeFor('tableau.csv'), 'text/csv');
    });

    test('.xmp, .cube, .lut et les extensions inconnues sont refusés (à mettre dans un zip)', () {
      for (final f in ['a.xmp', 'b.cube', 'c.lut', 'd.exe', 'sans_extension', 'point.']) {
        expect(PaidFileTypes.isAccepted(f), isFalse, reason: f);
      }
      expect(PaidFileTypes.isAccepted('preset.zip'), isTrue);
    });

    test('les listes par genre ne contiennent que des types connus', () {
      for (final e in [...PaidFileTypes.audio, ...PaidFileTypes.video, ...PaidFileTypes.documents, ...PaidFileTypes.archives]) {
        expect(PaidFileTypes.mimeByExtension, contains(e), reason: e);
      }
      expect(PaidFileTypes.audioMaxMb, 50);
    });
  });
}
