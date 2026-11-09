import '../pages/studio/montage/montage_catalog.dart';
import 'post_widget.dart';

/// Un emplacement de média demandé par un modèle (« Ta vidéo », « La photo d'avant »…).
class TemplateSlot {
  const TemplateSlot(this.kind, this.label);

  /// `video`, `image` ou `any`.
  final String kind;
  final String label;
}

/// Catégories d'un modèle de créateur (celles du Studio, plus « fun » et « business »).
const kCommunityCategories = <String, String>{
  'fun': 'Fun',
  'situations': 'Situations',
  'emotions': 'Émotions',
  'insta': 'Insta',
  'music': 'Musique',
  'culture': 'Culture',
  'fetes': 'Fêtes',
  'business': 'Business',
};

/// Prix permis pour un modèle de créateur, en pièces (0 = gratuit).
const kCommunityPrices = <int>[0, 10, 20, 30, 50];

/// Modèle prêt à poster créé par une personne (09/11/2026) : une RECETTE (modèle de base du Studio, textes, widgets, musique, emplacements, filtres de visage) que le serveur
/// a validée, un prix en pièces et un compteur d'utilisations. Les gains du créateur se montrent en pièces seulement, jamais en pourcentage.
class CommunityTemplate {
  CommunityTemplate({
    required this.id,
    required this.name,
    required this.category,
    required this.priceCoins,
    required this.recipe,
    this.usesCount = 0,
    this.ownerId,
    this.ownerName,
    this.ownerAvatar,
    this.mine = false,
    this.status,
    this.refusalReason,
    this.earnedCoins = 0,
  });

  final String id;
  final String name;
  final String category;
  final int priceCoins;
  final Map<String, dynamic> recipe;
  final int usesCount;
  final String? ownerId;
  final String? ownerName;
  final String? ownerAvatar;
  final bool mine;

  /// Seulement pour son créateur : `pending_review`, `validated`, `refused` ou `suspended`.
  final String? status;
  final String? refusalReason;
  final int earnedCoins;

  /// Modèles déjà vus, par code (`u:{id}`) : le prix et le créateur sont retrouvés à la publication sans nouvel appel.
  static final Map<String, CommunityTemplate> known = {};

  static final RegExp _idRe = RegExp(r'^[a-z0-9]{26}$');
  static bool validId(String id) => _idRe.hasMatch(id);

  String get code => 'u:$id';

  /// Gratuit pour la personne : prix à 0, ou son propre modèle.
  bool get isFree => priceCoins <= 0 || mine;

  String get baseId => '${recipe['base'] ?? ''}'.startsWith('m:') ? '${recipe['base']}'.substring(2) : '';

  Map<String, dynamic> get texts => Map<String, dynamic>.from((recipe['texts'] as Map?) ?? const {});

  String? get musicId {
    final m = recipe['music'];
    return m is String && m.isNotEmpty ? m : null;
  }

  List<TemplateSlot> get slots {
    final raw = (recipe['slots'] as List?) ?? const [];
    final list = [for (final s in raw.whereType<Map>()) TemplateSlot('${s['kind'] ?? 'any'}', '${s['label'] ?? ''}')];
    return list.isEmpty ? const [TemplateSlot('any', 'Ta photo ou vidéo')] : list;
  }

  String get layout => '${recipe['layout'] ?? 'single'}';

  TemplateFace? get face {
    final f = recipe['face'];
    if (f is! Map) return null;
    final out = TemplateFace(avatar: f['avatar'] as String?, magic: f['magic'] as String?, gesture: f['gesture'] as String?);
    return out.isEmpty ? null : out;
  }

  /// Widgets de la recette, prêts à poser : les échéances (« dans 14 jours à 18 h ») sont calculées maintenant.
  List<PostWidget> presetWidgets() {
    final out = <PostWidget>[];
    for (final w in ((recipe['widgets'] as List?) ?? const []).whereType<Map>()) {
      final kind = WidgetKindX.fromId(w['type'] as String?);
      if (kind == null) continue;
      final c = Map<String, dynamic>.from((w['config'] as Map?) ?? const {});
      if (kind == WidgetKind.countdown || kind == WidgetKind.reminder) {
        c['at'] = montageInDays((c.remove('in_days') as num?)?.toInt() ?? 7, (c.remove('hour') as num?)?.toInt() ?? 18);
      }
      out.add(PostWidget(kind: kind, config: c, x: (w['x'] as num?)?.toDouble() ?? .5, y: (w['y'] as num?)?.toDouble() ?? .5, scale: (w['scale'] as num?)?.toDouble() ?? 1));
    }
    return out;
  }

  /// Le modèle du Studio qui le porte (null si ce modèle de base n'existe pas dans cette version de l'application : le modèle est alors indisponible ici).
  MontageTemplate? toMontage() {
    final base = kMontageTemplates.where((t) => t.id == baseId).firstOrNull;
    if (base == null) return null;
    known[code] = this;
    final t = texts;
    final lines = [for (final l in (t['lines'] as List?) ?? const []) '$l'];
    return base.derive(
      id: 'u_$id',
      name: name,
      kick: t['kick'] as String?,
      title: t['title'] as String?,
      chip: t['chip'] as String?,
      texts: lines.isEmpty ? null : lines,
      musicId: musicId,
      presetWidgets: presetWidgets,
      face: face,
    );
  }

  static CommunityTemplate fromApi(Map j) {
    final owner = j['owner'] is Map ? Map<String, dynamic>.from(j['owner'] as Map) : const <String, dynamic>{};
    final t = CommunityTemplate(
      id: '${j['id']}',
      name: '${j['name'] ?? ''}',
      category: '${j['category'] ?? 'fun'}',
      priceCoins: (j['price_coins'] as num?)?.toInt() ?? 0,
      recipe: Map<String, dynamic>.from((j['recipe'] as Map?) ?? const {}),
      usesCount: (j['uses_count'] as num?)?.toInt() ?? 0,
      ownerId: owner['id'] as String?,
      ownerName: owner['username'] as String?,
      ownerAvatar: owner['avatar_url'] as String?,
      mine: j['mine'] == true,
      status: j['status'] as String?,
      refusalReason: j['refusal_reason'] as String?,
      earnedCoins: (j['earned_coins'] as num?)?.toInt() ?? 0,
    );
    known[t.code] = t;
    return t;
  }

  /// Recette d'un modèle créé depuis le Studio : le modèle de base, les textes, la musique de la bibliothèque (jamais un fichier de la personne) et les widgets
  /// sans donnée personnelle (compte à rebours, rappel, lieu, question, sondage, quiz, réaction ; l'échéance devient « dans N jours »).
  static Map<String, dynamic> buildRecipe({
    required String baseId,
    String? kick,
    String? title,
    String? chip,
    List<String> lines = const [],
    String? musicId,
    List<PostWidget> widgets = const [],
    List<TemplateSlot> slots = const [],
    String layout = 'single',
    TemplateFace? face,
  }) {
    const allowed = {WidgetKind.countdown, WidgetKind.reminder, WidgetKind.place, WidgetKind.question, WidgetKind.poll, WidgetKind.quiz, WidgetKind.reaction};
    final out = <Map<String, dynamic>>[];
    for (final w in widgets) {
      if (!allowed.contains(w.kind) || out.length >= PostWidgetsLink.max) continue;
      var config = Map<String, dynamic>.from(w.config);
      if (w.kind == WidgetKind.countdown || w.kind == WidgetKind.reminder) {
        final at = DateTime.tryParse('${config['at']}')?.toLocal();
        final days = at == null ? 7 : at.difference(DateTime.now()).inDays.clamp(1, 365);
        config = {'title': '${config['title'] ?? ''}', 'in_days': days, 'hour': at?.hour ?? 18};
      } else if (w.kind == WidgetKind.place) {
        config = {'name': '${config['name'] ?? ''}', 'maps_url': ''};
      }
      out.add({'type': w.kind.id, 'config': config, 'x': w.x, 'y': w.y, 'scale': w.scale});
    }
    return {
      'v': 1,
      'base': 'm:$baseId',
      'texts': {
        if (kick != null && kick.trim().isNotEmpty) 'kick': kick.trim(),
        if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
        if (chip != null && chip.trim().isNotEmpty) 'chip': chip.trim(),
        if (lines.isNotEmpty) 'lines': lines,
      },
      'widgets': out,
      'music': musicId,
      'slots': [for (final s in (slots.isEmpty ? const [TemplateSlot('any', 'Ta photo ou vidéo')] : slots)) {'kind': s.kind, 'label': s.label}],
      'layout': layout,
      if (face != null && !face.isEmpty) 'face': {if (face.avatar != null) 'avatar': face.avatar, if (face.magic != null) 'magic': face.magic, if (face.gesture != null) 'gesture': face.gesture},
    };
  }
}
