/// Où insérer les pubs dans une liste, même quand elle est plus courte que prévu.
///
/// Règle : une pub après le [first]ᵉ élément, puis toutes les [every] suites. Si la liste a moins de
/// [first] éléments (ou en a peu), on place quand même UNE pub en fin de liste. Une liste vide
/// affiche sa pub dans son état vide (voir `AdSlot` avec `kind` adapté).
class AdPositions {
  AdPositions._();

  /// Indices (à partir de 0) des éléments APRÈS lesquels insérer une pub.
  static List<int> after(int itemCount, {required int first, required int every}) {
    if (itemCount <= 0) return const [];
    final out = <int>[];
    for (var i = first - 1; i < itemCount; i += every) {
      out.add(i);
    }
    if (out.isEmpty) out.add(itemCount - 1); // liste plus courte que prévu : pub en fin de liste
    return out;
  }
}
