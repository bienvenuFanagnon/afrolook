import 'package:afrotok/services/weekly_rewards_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('le classement des créateurs lit les chiffres réels envoyés par l’API', () {
    final r = WeeklyCreatorRanking.fromMap({
      'rank': 1, 'entity_id': 'u1', 'is_channel': false, 'score': 120.5, 'post_count': 3,
      'unique_lovers': 14, 'unique_commenters': 5, 'comments': 9, 'total_views': 230, 'shares': 2, 'interactions': 25,
    });
    expect(r.uniqueLovers, 14);
    expect(r.comments, 9);
    expect(r.totalViews, 230);
    expect(r.totalInteractions, 25);
  });

  test('un ancien classement enregistré sans total garde un total calculé', () {
    final r = WeeklyCreatorRanking.fromMap({'rank': 2, 'entity_id': 'u2', 'score': 10, 'post_count': 1, 'unique_lovers': 4, 'unique_commenters': 3});
    expect(r.totalInteractions, 7);
  });
}
