import 'package:afrotok/ads/ad_backoff.dart';
import 'package:flutter_test/flutter_test.dart';

/// Moins de demandes de pubs pour rien (08/11/2026) : attente après un échec, pub plein écran demandée seulement si elle peut passer.
void main() {
  setUp(AdBackoff.reset);

  group('AdBackoff', () {
    test('après un échec on attend 45 s, puis 90 s, puis 3 min au plus ; un succès remet à zéro', () {
      final t = DateTime(2026, 11, 8, 12);
      expect(AdBackoff.blocked('x', now: t), isFalse);
      AdBackoff.failed('x', now: t);
      expect(AdBackoff.blocked('x', now: t.add(const Duration(seconds: 44))), isTrue);
      expect(AdBackoff.blocked('x', now: t.add(const Duration(seconds: 46))), isFalse);
      AdBackoff.failed('x', now: t.add(const Duration(minutes: 1)));
      expect(AdBackoff.blocked('x', now: t.add(const Duration(minutes: 2, seconds: 20))), isTrue);   // 90 s après le 2e échec
      AdBackoff.failed('x', now: t.add(const Duration(minutes: 5)));
      AdBackoff.failed('x', now: t.add(const Duration(minutes: 9)));
      expect(AdBackoff.blocked('x', now: t.add(const Duration(minutes: 11, seconds: 50))), isTrue);
      expect(AdBackoff.blocked('x', now: t.add(const Duration(minutes: 12, seconds: 10))), isFalse);   // jamais plus de 3 min
      AdBackoff.succeeded('x');
      AdBackoff.failed('x', now: t);
      expect(AdBackoff.blocked('x', now: t.add(const Duration(seconds: 46))), isFalse);   // reparti du premier palier
    });

    test('chaque sorte de pub a sa propre attente', () {
      final t = DateTime(2026, 11, 8, 12);
      AdBackoff.failed('interstitial', now: t);
      expect(AdBackoff.blocked('interstitial', now: t), isTrue);
      expect(AdBackoff.blocked('rewarded', now: t), isFalse);
    });
  });

  group('AdPlan.interstitialWorthLoading', () {
    bool plan({int closed = 3, int every = 4, int sinceStart = 20, int warmup = 5, int? sinceLast, int gap = 5, bool cap = true}) => AdPlan.interstitialWorthLoading(
          videosClosed: closed,
          every: every,
          sinceSessionStart: Duration(minutes: sinceStart),
          warmupMinutes: warmup,
          sinceLastInterstitial: sinceLast == null ? null : Duration(minutes: sinceLast),
          minGapMinutes: gap,
          underDailyCap: cap,
        );

    test('oui quand la prochaine vidéo fermée sera la 4e et que tout est permis', () => expect(plan(), isTrue));
    test('non quand ce n\'est pas la vidéo du rang', () {
      expect(plan(closed: 0), isFalse);
      expect(plan(closed: 1), isFalse);
      expect(plan(closed: 4), isFalse);
    });
    test('non pendant les premières minutes de la session, oui à une minute de la fin', () {
      expect(plan(sinceStart: 2), isFalse);
      expect(plan(sinceStart: 4), isTrue);
    });
    test('non juste après une autre pub plein écran, oui quand l\'écart est presque écoulé', () {
      expect(plan(sinceLast: 1), isFalse);
      expect(plan(sinceLast: 4), isTrue);
      expect(plan(sinceLast: 30), isTrue);
    });
    test('non quand le plafond du jour est atteint', () => expect(plan(cap: false), isFalse));
  });
}
