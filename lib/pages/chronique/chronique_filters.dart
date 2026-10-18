import 'chroniqueform.dart';

/// Filtres de la liste des chroniques. Ils s'appliquent aux chroniques déjà chargées : aucune lecture de plus.
enum ChroniqueFilter { forYou, following, popular, videos, music }

String chroniqueFilterLabel(ChroniqueFilter f) {
  switch (f) {
    case ChroniqueFilter.forYou:
      return 'Pour toi';
    case ChroniqueFilter.following:
      return 'Abonnements';
    case ChroniqueFilter.popular:
      return 'Populaires';
    case ChroniqueFilter.videos:
      return 'Vidéos';
    case ChroniqueFilter.music:
      return 'Musique';
  }
}

int _score(List<Chronique> g) => g.fold<int>(0, (a, c) => a + c.viewCount + 3 * (c.likeCount + c.loveCount) + 2 * c.commentCount);

/// Groupes (une personne = un groupe de chroniques) après filtre et recherche par pseudo.
/// Ordre : les plus récents d'abord, sauf « Populaires » (score de vues, j'aime et commentaires).
List<List<Chronique>> applyChroniqueFilter(
  Iterable<List<Chronique>> groups,
  ChroniqueFilter filter, {
  Set<String> followedIds = const {},
  String query = '',
}) {
  final q = query.trim().toLowerCase().replaceFirst(RegExp(r'^@'), '');
  var out = [
    for (final g in groups)
      if (g.isNotEmpty) ([...g]..sort((a, b) => b.createdAt.compareTo(a.createdAt)))
  ];
  if (q.isNotEmpty) out = out.where((g) => g.first.userPseudo.toLowerCase().contains(q)).toList();
  switch (filter) {
    case ChroniqueFilter.forYou:
      break;
    case ChroniqueFilter.following:
      out = out.where((g) => followedIds.contains(g.first.userId)).toList();
      break;
    case ChroniqueFilter.popular:
      out = out.where((g) => _score(g) > 0).toList();
      out.sort((a, b) => _score(b).compareTo(_score(a)));
      return out;
    case ChroniqueFilter.videos:
      out = out.where((g) => g.any((c) => c.type == ChroniqueType.VIDEO)).toList();
      break;
    case ChroniqueFilter.music:
      out = out.where((g) => g.any((c) => c.hasMusic || c.type == ChroniqueType.AUDIO)).toList();
      break;
  }
  out.sort((a, b) => b.first.createdAt.compareTo(a.first.createdAt));
  return out;
}

/// Hauteurs des cartes (deux colonnes, alternées) : même rythme à chaque bloc de 6 personnes.
const List<double> kChroniqueLeftHeights = [176, 132, 150];
const List<double> kChroniqueRightHeights = [140, 190, 128];
