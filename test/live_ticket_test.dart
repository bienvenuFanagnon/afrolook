import 'package:afrotok/services/api/live_ticket.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('billet : la réponse du jeton donne la fin du billet et le « son seul »', () {
    final end = DateTime.now().add(const Duration(minutes: 10)).toUtc().toIso8601String();
    final t = LiveTicket.fromToken({'by': 'ticket', 'kind': 'audio', 'ends_at': end})!;
    expect(t.by, 'ticket');
    expect(t.audioOnly, isTrue);
    expect(t.secondsLeft, inInclusiveRange(595, 600));
  });

  test('billet : tant que le gratuit dure, rien à compter', () {
    expect(LiveTicket.fromToken(null), isNull);
    expect(const LiveTicket().secondsLeft, greaterThan(1 << 29));
  });

  test('billet : une fin passée donne 0 seconde', () {
    final t = LiveTicket(endsAt: DateTime.now().subtract(const Duration(seconds: 5)));
    expect(t.secondsLeft, 0);
  });

  test('prix du billet : lus dans le refus 402 et dans la fiche du live', () {
    final o = LiveTicketOffer.fromDetails({'coins': 50, 'minutes': 15, 'tier': 'video', 'audio_coins': 13})!;
    expect(o.coins, 50);
    expect(o.audioCoins, 13);
    expect(o.isAudioRoom, isFalse);
    expect(LiveTicketOffer.fromDetails({'tier': 'audio', 'coins': 13, 'audio_coins': 13})!.isAudioRoom, isTrue);
    expect(LiveTicketOffer.fromDetails({}), isNull);
    final f = LiveTicketOffer.fromLive({
      'me': {'ticket': {'mode': 'ticket', 'coins': 110, 'minutes': 15, 'tier': 'stage', 'audio_coins': 13}}
    })!;
    expect(f.coins, 110);
    // gratuit du mois pas épuisé : aucun prix à afficher
    expect(LiveTicketOffer.fromLive({'me': {'ticket': {'mode': 'free', 'coins': 50}}}), isNull);
  });

  test('frais de diffusion de l\'hôte : échéance lue, 0 seconde une fois passée', () {
    final f = LiveHostFee.fromJson({'coins': 50, 'paid_until': DateTime.now().add(const Duration(seconds: 90)).toUtc().toIso8601String()})!;
    expect(f.coins, 50);
    expect(f.secondsLeft, inInclusiveRange(85, 90));
    expect(LiveHostFee.fromJson({'coins': 50, 'paid_until': null})!.secondsLeft, 0);
    expect(LiveHostFee.fromJson(null), isNull);
  });
}
