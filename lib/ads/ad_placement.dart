/// Règles de placement des pubs dans les listes, sans dépendance à l'interface (testables).
class AdPlacement {
  AdPlacement._();

  /// Nombres de lignes après lesquels intercaler une pub : [startAt], puis toutes les [every] lignes.
  /// Jamais avant la ligne [pinned] + 1 (les épinglées restent en tête) ni après la dernière ligne.
  static List<int> afterRows(int itemCount, {required int startAt, required int every, int pinned = 0}) {
    final out = <int>[];
    var next = startAt > pinned ? startAt : pinned + 1;
    while (next < itemCount) {
      out.add(next);
      next += every;
    }
    return out;
  }
}
