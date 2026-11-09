// Lien entre un post et le template (Studio) ou le modèle de carte qui l'a servi : « Essayer ce template » sous le post,
// comme sur TikTok. La référence est un petit texte stocké dans le post (champ `studioTemplate`) :
//   m:{id}            template du Studio (montage), ex. m:noel
//   c:{style}         carte Afrolook d'un style, ex. c:music
//   c:{style}:{modèle} carte d'un style avec un modèle de formulaire, ex. c:neon:birthday
//   u:{id}            modèle créé par une personne (09/11/2026), ex. u:01k9...

import 'dart:math';

import 'package:afrotok/services/api/regie_api.dart';
import 'package:afrotok/services/api/wallet_api.dart';

import '../models/community_template.dart';
import '../pages/cards/card_models.dart';
import '../pages/studio/montage/montage_catalog.dart';

class TemplateRef {
  const TemplateRef.montage(this.id)
      : kind = 'm',
        sub = null;
  const TemplateRef.card(this.id, [this.sub]) : kind = 'c';
  const TemplateRef.community(this.id)
      : kind = 'u',
        sub = null;

  final String kind; // 'm' Studio · 'c' carte · 'u' modèle d'une personne
  final String id; // id du template Studio, ou nom du style de carte
  final String? sub; // nom du modèle de carte

  bool get isMontage => kind == 'm';
  bool get isCard => kind == 'c';
  bool get isCommunity => kind == 'u';

  String get code => isMontage ? 'm:$id' : (isCommunity ? 'u:$id' : (sub == null ? 'c:$id' : 'c:$id:$sub'));

  MontageTemplate? get montage => isMontage ? kMontageTemplates.where((t) => t.id == id).firstOrNull : null;
  CardStyleId? get cardStyle => isCard ? CardStyleId.values.where((s) => s.name == id).firstOrNull : null;
  CardTemplateId? get cardTemplate => sub == null ? null : CardTemplateId.values.where((s) => s.name == sub).firstOrNull;

  /// Lisible : « Noël », « Carte Néon · Anniversaire ».
  String get label {
    if (isMontage) return montage?.name ?? '';
    if (isCommunity) return CommunityTemplate.known[code]?.name ?? '';
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
    if (p[0] == 'u' && p.length == 2 && CommunityTemplate.validId(p[1])) return TemplateRef.community(p[1]);   // le modèle lui-même se charge à l'ouverture (il peut avoir été retiré)
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
    if (id.startsWith('u_')) return parse('u:${id.substring(2)}');   // modèle d'une personne : son identifiant est celui du serveur
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
  static String? _jobId;   // identifiant du montage payé (modèle payant d'une personne)

  /// Début d'un « Essayer ce template » depuis le post [fromPostId].
  static void begin(String? fromPostId) => _fromPostId = fromPostId;

  static void set(String? code) {
    _ref = code;
    _jobId = (code != null && code.startsWith('u:')) ? _newJob() : null;
  }

  static String _newJob() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final r = Random.secure();
    return 'tpl' + List.generate(21, (_) => chars[r.nextInt(chars.length)]).join();
  }

  /// Le modèle de ce post est-il payant pour la personne ? (modèle d'une personne, prix en pièces, pas le sien.)
  static CommunityTemplate? get _paid {
    final c = _ref;
    final t = c == null ? null : CommunityTemplate.known[c];
    return (t == null || t.isFree) ? null : t;
  }

  /// Avant de publier : paie l'utilisation d'un modèle payant (une seule fois par publication : la clé d'achat dépend du montage). Les erreurs (solde insuffisant…) remontent
  /// telles quelles à l'écran de publication. Gratuit, ou son propre modèle : rien.
  static Future<void> payIfNeeded() async {
    final t = _paid;
    final job = _jobId;
    if (t == null || job == null) return;
    await WalletApi.instance.buy('template_use', refId: t.id, jobId: job);
  }

  /// Identifiant du montage payé à envoyer avec la publication de ce modèle (null : modèle gratuit ou autre).
  static String? jobIdFor(String? code) => code != null && code == _ref && _paid != null ? _jobId : null;

  static void clear() {
    _ref = null;
    _fromPostId = null;
    _jobId = null;
  }

  /// Champs à ajouter au document du post (vide sans template).
  static Map<String, dynamic> fields() => _ref == null ? const {} : {'studioTemplate': _ref};

  /// Après la création du post : un essai de plus pour le post d'origine, jamais bloquant.
  static void published() {
    final src = _fromPostId;
    final had = _ref != null;
    _ref = null;
    _jobId = null;
    _fromPostId = null;
    if (src == null || !had) return;
    () async {
      try {
        await RegieApi.post('/posts/$src/template-try'); // route à fournir : voir lacunes_api_regie_admin.md
      } catch (_) {}
    }();
  }
}
