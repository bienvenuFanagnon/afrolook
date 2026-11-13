import 'dart:async';

import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:afrotok/services/feed/feed_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Réessai automatique du fil : seules les PANNES sont réessayées (réseau, délai dépassé, serveur occupé ou en erreur), jamais un refus de l'API.
ApiException api(int status, {String code = 'x'}) => ApiException(status: status, code: code, message: 'm');

void main() {
  test('pannes : réessayées', () {
    expect(FeedRepository.isRetryable(ApiException(status: 0, code: 'network', message: 'Pas de connexion.')), isTrue);
    expect(FeedRepository.isRetryable(api(500)), isTrue);
    expect(FeedRepository.isRetryable(api(502)), isTrue);
    expect(FeedRepository.isRetryable(api(503)), isTrue);
    expect(FeedRepository.isRetryable(api(429)), isTrue);
    expect(FeedRepository.isRetryable(api(408)), isTrue);
    expect(FeedRepository.isRetryable(TimeoutException('trop long')), isTrue);
  });

  test('refus de l\'API : jamais réessayés (connexion expirée, droits, requête invalide)', () {
    expect(FeedRepository.isRetryable(api(401)), isFalse);
    expect(FeedRepository.isRetryable(api(403)), isFalse);
    expect(FeedRepository.isRetryable(api(404)), isFalse);
    expect(FeedRepository.isRetryable(api(422)), isFalse);
  });
}
