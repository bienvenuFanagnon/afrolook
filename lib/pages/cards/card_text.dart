import 'card_models.dart';

/// Découpe du texte d'un post pour la carte : pure logique, sans dépendance à l'interface (testable).
///
/// Règle : on mesure d'abord (nombre de caractères maximal selon le format et la présence d'un média), puis on coupe
/// à la fin d'une phrase, sinon d'un mot, jamais au milieu d'un mot. Les hashtags et les liens quittent le texte et
/// passent en pied de carte. L'utilisateur peut aussi choisir lui-même les phrases à garder.

/// Texte nettoyé, et ce qui en est sorti.
class CardTextParts {
  const CardTextParts(this.body, this.tags, this.links);
  final String body;
  final List<String> tags;
  final List<String> links;
}

/// Nombre de caractères maximal du texte selon le format de carte et la présence d'un média.
/// Valeurs de départ : à affiner en testant sur de vrais posts.
int cardCharBudget(CardFormat format, {required bool hasMedia}) {
  switch (format) {
    case CardFormat.portrait:
      return hasMedia ? 140 : 380;
    case CardFormat.story:
      return hasMedia ? 260 : 600;
    case CardFormat.square:
      return hasMedia ? 90 : 260;
  }
}

final _tagRe = RegExp(r'(^|\s)(#[\p{L}\p{N}_]+)', unicode: true);
final _linkRe = RegExp(r'https?://\S+', caseSensitive: false);

/// Sépare le texte, les hashtags et les liens ; les espaces et sauts de ligne en trop sont nettoyés.
CardTextParts separateTags(String raw) {
  final links = _linkRe.allMatches(raw).map((m) => m.group(0)!).toList();
  var t = raw.replaceAll(_linkRe, ' ');
  final tags = _tagRe.allMatches(t).map((m) => m.group(2)!).toList();
  t = t.replaceAllMapped(_tagRe, (m) => m.group(1)!);
  t = t.replaceAll(RegExp(r'[ \t]+'), ' ').replaceAll(RegExp(r' ?\n ?'), '\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  return CardTextParts(t, tags, links);
}

final _sentenceRe = RegExp(r'[^.!?…\n]+(?:[.!?…]+["»”)\]]*|\n|$)', unicode: true);

/// Phrases du texte (ponctuation conservée), pour le mode « choisir les phrases ».
List<String> splitSentences(String body) {
  final out = <String>[];
  for (final m in _sentenceRe.allMatches(body)) {
    final s = m.group(0)!.replaceAll('\n', ' ').trim();
    if (s.isNotEmpty) out.add(s);
  }
  return out;
}

/// Résultat d'une coupe.
class CardCut {
  const CardCut(this.text, this.truncated);
  final String text;
  final bool truncated;
}

/// Coupe [body] pour tenir dans [budget] caractères : phrases entières d'abord, sinon un mot, avec « … ».
CardCut cutText(String body, int budget) {
  final t = body.trim();
  if (t.length <= budget) return CardCut(t, false);
  final sentences = splitSentences(t);
  final kept = StringBuffer();
  for (final s in sentences) {
    final next = kept.isEmpty ? s : '${kept.toString()} $s';
    if (next.length > budget) break;
    kept
      ..clear()
      ..write(next);
  }
  if (kept.isNotEmpty) return CardCut('${kept.toString()} …', true);
  // première phrase déjà trop longue : on coupe à un mot
  final room = budget - 2;
  var cut = t.substring(0, room < 1 ? 1 : room);
  final lastSpace = cut.lastIndexOf(' ');
  if (lastSpace > room * 0.5) cut = cut.substring(0, lastSpace);
  cut = cut.replaceAll(RegExp(r'[\s,;:.\-–]+$'), '');
  return CardCut('$cut …', true);
}

/// Texte retenu pour la carte, selon le mode choisi.
CardCut cardText(String raw, CardSpec spec, {required bool hasMedia}) {
  final body = separateTags(raw).body;
  final budget = cardCharBudget(spec.format, hasMedia: hasMedia);
  if (spec.textMode == CardTextMode.pick && spec.pickedSentences.isNotEmpty) {
    final s = splitSentences(body);
    final picked = (spec.pickedSentences.toList()..sort()).where((i) => i >= 0 && i < s.length).map((i) => s[i]).toList();
    if (picked.isNotEmpty) {
      final joined = picked.join(' ');
      final cut = cutText(joined, budget);
      return CardCut(cut.text, cut.truncated);
    }
  }
  return cutText(body, budget);
}
