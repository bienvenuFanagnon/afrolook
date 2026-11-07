import 'package:afrotok/services/nsfw_check.dart';
import 'package:flutter_test/flutter_test.dart';

// ordre des classes : drawings, hentai, neutral, porn, sexy
List<double> f({double porn = 0, double sexy = 0, double neutral = 0}) => [0.01, 0.01, neutral, porn, sexy];

void main() {
  test('une image très sûre suffit pour refuser', () {
    expect(NsfwCheck.decide([f(neutral: .9), f(porn: .9)]), isTrue);
  });

  test('deux images assez sûres refusent ; une seule image moyenne ne refuse pas', () {
    expect(NsfwCheck.decide([f(porn: .65), f(porn: .7), f(neutral: .9)]), isTrue);
    expect(NsfwCheck.decide([f(porn: .65), f(neutral: .9), f(neutral: .9)]), isFalse);
  });

  test('« sexy » et « neutral » passent, même avec de très forts scores sexy', () {
    expect(NsfwCheck.decide([f(sexy: .95), f(sexy: .9), f(sexy: .99)]), isFalse);
    expect(NsfwCheck.decide([f(neutral: .97), f(neutral: .93)]), isFalse);
    expect(NsfwCheck.decide([]), isFalse);
  });
}
