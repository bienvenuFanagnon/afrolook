import '../../models/model_data.dart';

/// Remonte les posts du pays de l'utilisateur, sans rien retirer du feed et
/// sans requête Firestore supplémentaire (donc sans index) : simple tri stable
/// côté appareil sur les posts déjà chargés (posts non vus, découverte…).
///
/// Ordre : posts ciblant explicitement son pays → posts de créateurs de son
/// pays → posts ciblant son continent → tous les autres. L'ordre d'origine est
/// conservé à l'intérieur de chaque groupe.
List<Post> prioritizeUserCountry(List<Post> posts, String? userCountryCode) {
  final code = userCountryCode?.trim().toUpperCase() ?? '';
  if (code.isEmpty || posts.length < 2) return posts;
  final continent = AfricanCountry.continentOf(code);

  int rank(Post p) {
    final targets = p.availableCountries.map((c) => c.toUpperCase()).toList();
    if (targets.contains(code)) return 0;
    final authorCountry = (p.user?.countryData?['countryCode'] ?? '').toUpperCase();
    if (authorCountry == code) return 1;
    if (continent != null && targets.any((c) => c != 'ALL' && AfricanCountry.continentOf(c) == continent)) return 2;
    return 3;
  }

  final indexed = [for (var i = 0; i < posts.length; i++) (i, rank(posts[i]), posts[i])];
  indexed.sort((a, b) => a.$2 != b.$2 ? a.$2.compareTo(b.$2) : a.$1.compareTo(b.$1));
  return [for (final e in indexed) e.$3];
}
