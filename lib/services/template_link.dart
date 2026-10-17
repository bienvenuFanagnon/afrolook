// Lien entre un post et le template (Studio) ou le modèle de carte qui l'a servi : « Essayer ce template » sous le post,
// comme sur TikTok. La référence est un petit texte stocké dans le post (champ `studioTemplate`) :
//   m:{id}            template du Studio (montage), ex. m:noel
//   c:{style}         carte Afrolook d'un style, ex. c:music
//   c:{style}:{modèle} carte d'un style avec un modèle de formulaire, ex. c:neon:birthday

import 'package:cloud_firestore/cloud_firestore.dart';

import '../pages/cards/card_models.dart';
import '../pages/studio/montage/montage_catalog.dart';

class TemplateRef {
  const TemplateRef.montage(this.id)
      : kind = 'm',
        sub = null;
  const TemplateRef.card(this.id, [this.sub]) : kind = 'c';

  final String kind; // 'm' Studio · 'c' carte
  final String id; // id du template Studio, ou nom du style de carte
  final String? sub; // nom du modèle de carte

  bool get isMontage => kind == 'm';
  bool get isCard => kind == 'c';

  String get code => isMontage ? 'm:$id' : (sub == null ? 'c:$id' : 'c:$id:$sub');

  MontageTemplate? get montage => isMontage ? kMontageTemplates.where((t) => t.id == id).firstOrNull : null;
  CardStyleId? get cardStyle => isCard ? CardStyleId.values.where((s) => s.name == id).firstOrNull : null;
  CardTemplateId? get cardTemplate => sub == null ? null : CardTemplateId.values.where((s) => s.name == sub).firstOrNull;

  /// Lisible : « Noël », « Carte Néon · Anniversaire ».
  String get label {
    if (isMontage) return montage?.name ?? '';
    final s = cardStyle;
    if (s == null) return '';
    final t = cardTemplate;
    return t == null ? 'Carte ${s.label}' : '${t.label} · ${s.label}';
  }

  /// Valide la référence contre les catalogues : un template supprimé ou inconnu ne montre pas de bouton.
  static TemplateRef? parse(String? code) {
    if (code == null || code.length < 3 || code.length > 60) return null;
    final p = code.split(':');
    TemplateRef? r;
    if (p[0] == 'm' && p.length == 2) r = TemplateRef.montage(p[1]);
    if (p[0] == 'c' && (p.length == 2 || p.length == 3)) r = TemplateRef.card(p[1], p.length == 3 ? p[2] : null);
    if (r == null) return null;
    if (r.isMontage) return r.montage == null ? null : r;
    if (r.cardStyle == null) return null;
    if (p.length == 3 && r.cardTemplate == null) return null;
    return r;
  }

  /// Référence d'un résultat du Studio (`montage_noel` → `m:noel`) ; null pour « Ma vidéo avec ce son » ou un template inconnu.
  static TemplateRef? fromStudioId(String? templateId) {
    if (templateId == null || !templateId.startsWith('montage_')) return null;
    final id = templateId.substring(8);
    if (id == kPlainTemplateId) return null;
    return parse('m:$id');
  }

  static TemplateRef fromCard(CardStyleId style, CardTemplateId? template) => TemplateRef.card(style.name, template?.name);
}

/// Mémorise le template du post en cours de création pour l'écrire dans le document du post, et compte les essais
/// (`templateTries`) sur le post d'origine quand quelqu'un publie avec « Essayer ce template ».
class PostTemplateLink {
  PostTemplateLink._();

  static String? _ref;
  static String? _fromPostId;

  /// Début d'un « Essayer ce template » depuis le post [fromPostId].
  static void begin(String? fromPostId) => _fromPostId = fromPostId;

  static void set(String? code) => _ref = code;

  static void clear() {
    _ref = null;
    _fromPostId = null;
  }

  /// Champs à ajouter au document du post (vide sans template).
  static Map<String, dynamic> fields() => _ref == null ? const {} : {'studioTemplate': _ref};

  /// Après la création du post : un essai de plus pour le post d'origine, jamais bloquant.
  static void published() {
    final src = _fromPostId;
    final had = _ref != null;
    _ref = null;
    _fromPostId = null;
    if (src == null || !had) return;
    () async {
      try {
        await FirebaseFirestore.instance.collection('Posts').doc(src).update({'templateTries': FieldValue.increment(1)});
      } catch (_) {}
    }();
  }
}
