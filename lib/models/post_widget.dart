import 'package:flutter/foundation.dart';

/// Types de widgets posés sur une publication. Décision du 07/11/2026 : aucun n'est réservé à Gold, 3 au plus par publication.
enum WidgetKind { poll, quiz, question, reaction, countdown, reminder, link, place, whatsapp, call, sale }

extension WidgetKindX on WidgetKind {
  String get id => name;

  /// Le public répond à ce widget (le serveur enregistre sa réponse).
  bool get interactive => const {WidgetKind.poll, WidgetKind.quiz, WidgetKind.question, WidgetKind.reaction, WidgetKind.reminder}.contains(this);

  String get emoji => switch (this) {
        WidgetKind.poll => '📊',
        WidgetKind.quiz => '🧠',
        WidgetKind.question => '❓',
        WidgetKind.reaction => '😍',
        WidgetKind.countdown => '⏳',
        WidgetKind.reminder => '🔔',
        WidgetKind.link => '🔗',
        WidgetKind.place => '📍',
        WidgetKind.whatsapp => '💬',
        WidgetKind.call => '📞',
        WidgetKind.sale => '🛍️',
      };

  /// Libellé français (traduit par `tr` à l'affichage).
  String get label => switch (this) {
        WidgetKind.poll => 'Sondage',
        WidgetKind.quiz => 'Quiz',
        WidgetKind.question => 'Question',
        WidgetKind.reaction => 'Réaction',
        WidgetKind.countdown => 'Compte à rebours',
        WidgetKind.reminder => 'Rappel',
        WidgetKind.link => 'Lien',
        WidgetKind.place => 'Lieu',
        WidgetKind.whatsapp => 'WhatsApp',
        WidgetKind.call => 'Appeler',
        WidgetKind.sale => 'Carte vente',
      };

  static WidgetKind? fromId(String? id) {
    for (final k in WidgetKind.values) {
      if (k.name == id) return k;
    }
    return null;
  }
}

/// Un widget : sa définition, sa place dans le cadre (fractions de 0 à 1) et, une fois publié, les décomptes et la réponse de la personne.
class PostWidget {
  PostWidget({
    this.id,
    required this.kind,
    required this.config,
    this.x = .5,
    this.y = .5,
    this.scale = 1,
    this.start,
    this.end,
    this.counts = const {},
    this.myValue,
    this.responsesCount = 0,
    this.isAuthor = false,
  });

  final String? id;
  final WidgetKind kind;
  final Map<String, dynamic> config;
  double x;
  double y;
  double scale;
  double? start;
  double? end;
  Map<String, int> counts;
  String? myValue;
  int responsesCount;
  bool isAuthor;   // la personne connectée a publié ce widget : elle lit les réponses

  String get question => '${config['question'] ?? config['title'] ?? config['label'] ?? config['name'] ?? config['product'] ?? ''}';

  List<String> get options => [for (final o in (config['options'] as List? ?? const [])) '$o'];

  /// Bonne réponse d'un quiz (connue seulement après avoir répondu, ou de l'auteur).
  int? get correct => config['correct'] is num ? (config['correct'] as num).toInt() : null;

  PostWidget copy() => PostWidget(id: id, kind: kind, config: Map<String, dynamic>.from(config), x: x, y: y, scale: scale, start: start, end: end, counts: Map.of(counts), myValue: myValue, responsesCount: responsesCount, isAuthor: isAuthor);

  Map<String, dynamic> toApi() => {
        'type': kind.id,
        'config': config,
        'x': double.parse(x.toStringAsFixed(3)),
        'y': double.parse(y.toStringAsFixed(3)),
        'scale': double.parse(scale.toStringAsFixed(2)),
        if (start != null) 'start': start,
        if (end != null) 'end': end,
      };

  static PostWidget? fromApi(Map j) {
    final kind = WidgetKindX.fromId(j['type'] as String?);
    if (kind == null) return null;
    final counts = <String, int>{};
    if (j['counts'] is Map) {
      (j['counts'] as Map).forEach((k, v) => counts['$k'] = (v as num).toInt());
    }
    return PostWidget(
      id: j['id'] as String?,
      kind: kind,
      config: j['config'] is Map ? Map<String, dynamic>.from(j['config'] as Map) : <String, dynamic>{},
      x: (j['x'] as num?)?.toDouble() ?? .5,
      y: (j['y'] as num?)?.toDouble() ?? .5,
      scale: (j['scale'] as num?)?.toDouble() ?? 1,
      start: (j['start'] as num?)?.toDouble(),
      end: (j['end'] as num?)?.toDouble(),
      counts: counts,
      myValue: j['my_value'] == null ? null : '${j['my_value']}',
      responsesCount: (j['responses_count'] as num?)?.toInt() ?? 0,
      isAuthor: j['is_author'] == true,
    );
  }

  /// Les widgets d'une réponse de l'API (liste de cartes), les inconnus sont ignorés.
  static List<PostWidget> listFromApi(Object? raw) => [for (final m in (raw is List ? raw : const []).whereType<Map>()) PostWidget.fromApi(m)].whereType<PostWidget>().toList();
}

/// Widgets en cours d'ajout dans le parcours de création (éditeur, puis « Nouveau post »), lus une seule fois par la publication.
class PostWidgetsLink {
  PostWidgetsLink._();

  static final ValueNotifier<List<PostWidget>> drafts = ValueNotifier<List<PostWidget>>(const []);

  static const max = 3;

  static bool get isFull => drafts.value.length >= max;

  static void add(PostWidget w) {
    if (isFull) return;
    drafts.value = [...drafts.value, w];
  }

  static void replace(PostWidget old, PostWidget w) => drafts.value = [for (final d in drafts.value) identical(d, old) ? w : d];

  static void remove(PostWidget w) => drafts.value = [for (final d in drafts.value) if (!identical(d, w)) d];

  static void clear() => drafts.value = const [];

  /// Pour la publication : les widgets au format de l'API, puis remise à zéro.
  static List<Map<String, dynamic>>? take() {
    final v = drafts.value;
    drafts.value = const [];
    return v.isEmpty ? null : [for (final w in v) w.toApi()];
  }
}
