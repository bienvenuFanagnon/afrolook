import 'package:afrolook_api_client/afrolook_api_client.dart';

import 'api_gateway.dart';

/// Carte Commerce d'une publication : prix, lieu, WhatsApp, appel et lien « Commander maintenant ».
class PostCommerce {
  const PostCommerce({required this.postId, required this.title, this.priceText, this.place, this.whatsapp, this.phone, this.linkUrl, this.linkLabel = 'Commander maintenant', this.linkTitle, this.linkImage, this.collapsed = true});

  final String postId;
  final String title;
  final String? priceText;
  final String? place;
  final String? whatsapp;
  final String? phone;
  final String? linkUrl;
  final String linkLabel;
  final String? linkTitle;
  final String? linkImage;

  /// Pastille réduite par défaut ; le spectateur la déplie d'un toucher.
  final bool collapsed;

  static String? _s(dynamic v) => v is String && v.trim().isNotEmpty ? v : null;

  factory PostCommerce.fromJson(Map<String, dynamic> j) => PostCommerce(
        postId: '${j['postId']}',
        title: '${j['title']}',
        priceText: _s(j['priceText']),
        place: _s(j['place']),
        whatsapp: _s(j['whatsapp']),
        phone: _s(j['phone']),
        linkUrl: _s(j['linkUrl']),
        linkLabel: _s(j['linkLabel']) ?? 'Commander maintenant',
        linkTitle: _s(j['linkTitle']),
        linkImage: _s(j['linkImage']),
        collapsed: j['collapsed'] != false,
      );

  Map<String, dynamic> toBody() => {
        'title': title,
        if (priceText != null) 'price_text': priceText,
        if (place != null) 'place': place,
        if (whatsapp != null) 'whatsapp': whatsapp,
        if (phone != null) 'phone': phone,
        if (linkUrl != null) 'link_url': linkUrl,
        'link_label': linkLabel,
        if (linkTitle != null) 'link_title': linkTitle,
        if (linkImage != null) 'link_image': linkImage,
        'collapsed': collapsed,
      };

  /// Adresse WhatsApp avec un message prêt (les seuls chiffres du numéro).
  Uri whatsappUri(String message) => Uri.parse('https://wa.me/${whatsapp!.replaceAll(RegExp(r'[^0-9]'), '')}?text=${Uri.encodeComponent(message)}');

  Uri callUri() => Uri.parse('tel:${phone!}');
}

/// Chiffres de la carte, visibles de l'auteur seulement.
class CommerceStats {
  const CommerceStats({this.opened = 0, this.whatsapp = 0, this.call = 0, this.link = 0});
  final int opened;
  final int whatsapp;
  final int call;
  final int link;
}

class CommerceApi {
  CommerceApi._();

  static ApiClient get _c => ApiGateway.instance.client;
  static final Map<String, PostCommerce?> _cache = {};

  static Map<String, dynamic> _map(dynamic r) {
    final d = ApiClient.data(r);
    return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
  }

  /// La carte d'un post (null s'il n'en a pas). Mise en cache : un post est lu une fois par session.
  static Future<PostCommerce?> get(String postId) async {
    if (_cache.containsKey(postId)) return _cache[postId];
    try {
      final c = PostCommerce.fromJson(_map(await _c.get('/posts/$postId/commerce')));
      return _cache[postId] = c;
    } on ApiException catch (e) {
      if (e.status == 404) return _cache[postId] = null;
      rethrow;
    }
  }

  static Future<PostCommerce> save(String postId, PostCommerce card) async {
    final c = PostCommerce.fromJson(_map(await _c.put('/posts/$postId/commerce', body: card.toBody())));
    _cache[postId] = c;
    return c;
  }

  static Future<void> remove(String postId) async {
    await _c.delete('/posts/$postId/commerce');
    _cache[postId] = null;
  }

  /// Un toucher sur la carte (`open`, `whatsapp`, `call`, `link`) : compté une fois par personne, par jour et par bouton. Sans effet sur l'écran si ça échoue.
  static Future<void> click(String postId, String kind) async {
    try {
      await _c.post('/posts/$postId/commerce/click', body: {'kind': kind});
    } catch (_) {}
  }

  static Future<CommerceStats> stats(String postId) async {
    final m = _map(await _c.get('/posts/$postId/commerce/stats'));
    int n(String k) => (m[k] as num?)?.toInt() ?? 0;
    return CommerceStats(opened: n('opened'), whatsapp: n('whatsapp'), call: n('call'), link: n('link'));
  }

  /// Aperçu d'un lien (titre et image de la page) pour la mini-carte « Commander maintenant ». `null` si la page ne peut pas être lue.
  static Future<({String? title, String? image})?> linkPreview(String url) async {
    try {
      final m = _map(await _c.get('/link-preview', query: {'url': url, 'purpose': 'card'}));
      final p = m['preview'];
      if (p is! Map) return null;
      String? s(dynamic v) => v is String && v.trim().isNotEmpty ? v : null;
      return (title: s(p['title']), image: s(p['image'] ?? p['imageUrl']));
    } catch (_) {
      return null;
    }
  }
}
