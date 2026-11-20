import 'package:afrotok/l10n/tr.dart';
import 'package:afrotok/pages/cinema/cinema_widgets.dart';
import 'package:afrotok/services/api/cinema_api.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cartoon Cinéma (21/11/2026) : formats affichés, droits de gestion, traductions.
void main() {
  test('nombres, durées et horloge du lecteur', () {
    expect(cinemaCount(950), '950');
    expect(cinemaCount(12400), '12,4 k');
    expect(cinemaCount(1500000), '1,5 M');
    expect(cinemaDuration(1320), '22 min');
    expect(cinemaDuration(5520), '1 h 32');
    expect(cinemaDuration(0), '');
    expect(cinemaClock(const Duration(seconds: 412)), '06:52');
    expect(cinemaClock(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03');
  });

  test('droits de gestion : un seul droit suffit pour ouvrir la gestion', () {
    expect(const CinemaRights().any, isFalse);
    expect(const CinemaRights(stats: true).any, isTrue);
    expect(const CinemaRights(create: true).delete, isFalse);
  });

  test('les six impressions et les textes principaux sont traduits', () {
    expect(kCinemaReactions.map((r) => r.$1).toList(), ['love', 'joy', 'laugh', 'wow', 'sad', 'angry']);
    expect(trFor('en', 'Regarder sur Cinéma'), 'Watch on Cinema');
    expect(trFor('en', '{a} s gratuites · Gold', {'a': 15}), '15 s free · Gold');
    expect(trFor('es', 'Voix en {a} · Aussi disponible en {b}', {'a': 'Français', 'b': 'English'}), 'Audio en Français · También disponible en English');
  });
}
