// Composant prêt à l'emploi d'Afrolook Ads : bannières d'applications (mini bannière du bas, grande bannière, rectangle moyen, leaderboard),
// et depuis le 17/11/2026 tous les autres formats : carte native, affiche, carrousel, vidéo, plein écran et récompensée (en bas du fichier).
// Même fichier pour nos applications et pour les diffuseurs (copie publiée sur https://afrolookmedia.com/ads/afrolook_ads_banner.dart).
//
// Dépendances : http, url_launcher, visibility_detector, video_player.
//
//   // mini bannière fixe en bas d'un écran (fermable, 320×50)
//   bottomNavigationBar: const AfrolookAdsBanner.bottom(pubId: 'ap_xxxxxxxxxx', visitorId: monIdentifiantDeVisiteur),
//   // rectangle moyen dans le contenu (300×250)
//   const AfrolookAdsBanner(pubId: 'ap_xxxxxxxxxx', visitorId: monIdentifiantDeVisiteur, size: AdsBannerSize.medium),
//
// Règles respectées : mention « Annonce » toujours visible, une vue envoyée seulement quand la bannière est visible à moitié pendant la durée du
// format, clic toujours par le lien d'Afrolook Ads (le serveur compte le clic puis ouvre l'annonceur), rien n'est affiché s'il n'y a pas d'annonce.
import 'dart:async';
import 'dart:convert';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Tailles standard (comme AdMob).
enum AdsBannerSize {
  /// 320 × 50 : mini bannière fixe en bas d'une application.
  mini(320, 50, '320x50', 'sticky'),

  /// 320 × 100 : grande bannière, dans une page sur téléphone.
  large(320, 100, '320x100', 'banner'),

  /// 300 × 250 : rectangle moyen, dans le contenu.
  medium(300, 250, '300x250', 'banner'),

  /// 728 × 90 : leaderboard, haut ou bas d'une page sur tablette ou ordinateur.
  leaderboard(728, 90, '728x90', 'banner');

  const AdsBannerSize(this.width, this.height, this.code, this.format);
  final double width;
  final double height;

  /// Valeur du paramètre `size` de /serve.
  final String code;

  /// Format de l'annonce demandé au moteur (prix et intervalles propres à chaque format).
  final String format;
}

class AfrolookAdsBanner extends StatefulWidget {
  const AfrolookAdsBanner({
    super.key,
    required this.pubId,
    required this.visitorId,
    this.size = AdsBannerSize.large,
    this.slot = 'banner',
    this.refresh = const Duration(seconds: 60),
    this.closable = false,
    this.headers,
    this.apiBase = 'https://afrolookmedia.com/ads/api',
  });

  /// Mini bannière fixe en bas d'un écran : 320 × 50, fermable, centrée, avec la marge de sécurité de l'écran.
  const AfrolookAdsBanner.bottom({
    super.key,
    required this.pubId,
    required this.visitorId,
    this.slot = 'bottom',
    this.refresh = const Duration(seconds: 60),
    this.headers,
    this.apiBase = 'https://afrolookmedia.com/ads/api',
  })  : size = AdsBannerSize.mini,
        closable = true;

  /// Identifiant publicitaire du site ou de l'application (ap_xxxxxxxxxx).
  final String pubId;

  /// Identifiant du visiteur : une chaîne de 12 à 64 caractères (lettres, chiffres, tirets), STABLE d'une session à l'autre (à garder dans les préférences).
  final String visitorId;
  final AdsBannerSize size;

  /// Nom de l'emplacement (lettres minuscules, chiffres, - et _), unique par emplacement de l'écran.
  final String slot;

  /// Délai avant une nouvelle annonce tant que la bannière reste à l'écran (au moins 30 s : intervalle minimum du moteur).
  final Duration refresh;

  /// Affiche une croix de fermeture (obligatoire pour la mini bannière du bas).
  final bool closable;

  /// En-têtes ajoutés aux appels (ex. `X-Firebase-AppCheck` pour une application attestée).
  final Future<Map<String, String>> Function()? headers;
  final String apiBase;

  @override
  State<AfrolookAdsBanner> createState() => _AfrolookAdsBannerState();
}

class _Ad {
  _Ad(this.json);
  final Map<String, dynamic> json;
  String get id => '${json['id']}';
  String get title => '${json['title'] ?? ''}';
  String get text => '${json['text'] ?? ''}';
  String get cta => '${json['cta'] ?? ''}'.isEmpty ? 'En savoir plus' : '${json['cta']}';
  String get click => '${json['click'] ?? ''}';
  String get token => '${json['token']}';
  String get event => '${json['event']}';
  int get viewMs => (json['viewMs'] as num?)?.toInt() ?? 1000;
  String get bannerUrl => (json['banner'] is Map) ? '${(json['banner'] as Map)['url'] ?? ''}' : '';
  String get imageUrl {
    final m = json['media'];
    return m is Map ? '${m['thumb'] ?? m['url'] ?? ''}' : '';
  }
}

class _AfrolookAdsBannerState extends State<AfrolookAdsBanner> {
  _Ad? _ad;
  bool _closed = false;
  bool _sent = false;
  Timer? _viewTimer;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _viewTimer?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final q = {
        'pub': widget.pubId,
        'fmt': widget.size.format,
        'size': widget.size.code,
        'slot': widget.slot,
        'vid': widget.visitorId,
      };
      final extra = widget.headers == null ? <String, String>{} : await widget.headers!();
      final res = await http.get(Uri.parse('${widget.apiBase}/serve').replace(queryParameters: q), headers: extra).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200 || !mounted) return;
      final j = jsonDecode(res.body);
      final ad = j is Map ? j['ad'] : null;
      setState(() {
        _ad = ad is Map<String, dynamic> && ad['token'] != null ? _Ad(ad) : null;
        _sent = false;
      });
    } catch (_) {
      // aucune annonce : l'emplacement reste vide
    }
    _refreshTimer?.cancel();
    final delay = widget.refresh < const Duration(seconds: 30) ? const Duration(seconds: 30) : widget.refresh;
    _refreshTimer = Timer(delay, () { if (mounted && !_closed) _load(); });
  }

  /// Une vue = au moins la moitié de la bannière visible, sans interruption, pendant la durée du format.
  void _visibility(VisibilityInfo info) {
    final ad = _ad;
    if (ad == null || _sent) return;
    _viewTimer?.cancel();
    if (info.visibleFraction >= 0.5) {
      _viewTimer = Timer(Duration(milliseconds: ad.viewMs + 50), () async {
        if (!mounted || _sent) return;
        _sent = true;
        try {
          final extra = widget.headers == null ? <String, String>{} : await widget.headers!();
          await http.post(
            Uri.parse(ad.event),
            headers: {'Content-Type': 'text/plain', ...extra},
            body: jsonEncode({'t': ad.token, 'e': 'view', 'ms': ad.viewMs + 50, 'vid': widget.visitorId}),
          ).timeout(const Duration(seconds: 8));
        } catch (_) {/* tant pis : la vue n'est simplement pas comptée */}
      });
    }
  }

  void _open(_Ad ad) {
    if (ad.click.isEmpty) return;
    launchUrl(Uri.parse(ad.click), mode: LaunchMode.externalApplication); // le serveur compte le clic puis ouvre l'annonceur
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null || _closed) return const SizedBox.shrink();
    final w = widget.size.width, h = widget.size.height;
    final body = ad.bannerUrl.isNotEmpty ? _readyBanner(ad, w, h) : _template(ad, w, h);
    final tagged = Stack(children: [
      body,
      // mention obligatoire
      Positioned(left: 0, top: 0, child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: const BoxDecoration(color: Color(0xB3000000), borderRadius: BorderRadius.only(bottomRight: Radius.circular(6))),
        child: const Text('Annonce', style: TextStyle(color: Colors.white, fontSize: 9, height: 1.3)),
      )),
      if (widget.closable)
        Positioned(right: 0, top: 0, child: GestureDetector(
          onTap: () => setState(() => _closed = true),
          child: Container(
            width: 24, height: 24, alignment: Alignment.center,
            decoration: const BoxDecoration(color: Color(0xB3000000), borderRadius: BorderRadius.only(bottomLeft: Radius.circular(6))),
            child: const Icon(Icons.close, size: 14, color: Colors.white),
          ),
        )),
    ]);
    return VisibilityDetector(
      key: Key('afrolook-ads-${widget.slot}-${ad.id}-${ad.token.hashCode}'),
      onVisibilityChanged: _visibility,
      child: SafeArea(
        top: false,
        child: Center(child: SizedBox(width: w, height: h, child: ClipRRect(borderRadius: BorderRadius.circular(6), child: tagged))),
      ),
    );
  }

  /// Bannière déjà dessinée par l'annonceur : l'image ENTIÈRE, cliquable, rien d'ajouté.
  Widget _readyBanner(_Ad ad, double w, double h) => GestureDetector(
        onTap: () => _open(ad),
        child: Image.network(ad.bannerUrl, width: w, height: h, fit: BoxFit.contain, errorBuilder: (_, __, ___) => _template(ad, w, h)),
      );

  /// Sans bannière à cette taille : image (entière, sur sa copie floutée), titre, texte et bouton mis en page automatiquement.
  Widget _template(_Ad ad, double w, double h) {
    final compact = h <= 60;
    final thumb = SizedBox(
      width: compact ? h : (h <= 110 ? h : w),
      height: compact ? h : (h <= 110 ? h : 140),
      child: ad.imageUrl.isEmpty
          ? const ColoredBox(color: Color(0xFF222222))
          : Stack(fit: StackFit.expand, children: [
              Image.network(ad.imageUrl, fit: BoxFit.cover, color: Colors.black54, colorBlendMode: BlendMode.darken, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              Image.network(ad.imageUrl, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
            ]),
    );
    final texts = Expanded(
      child: Padding(
        padding: EdgeInsets.fromLTRB(8, compact ? 2 : 14, 8, 2),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(ad.title, maxLines: compact ? 1 : 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: compact ? 12 : 14, height: 1.2)),
          if (!compact && ad.text.isNotEmpty) Text(ad.text, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 12, height: 1.3)),
        ]),
      ),
    );
    final button = Padding(
      padding: const EdgeInsets.only(right: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(color: const Color(0xFFFFB830), borderRadius: BorderRadius.circular(999)),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14, vertical: compact ? 5 : 8),
          child: Text(ad.cta, style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: compact ? 11 : 12.5)),
        ),
      ),
    );
    final stacked = h > 110; // rectangle moyen : image au-dessus, texte puis bouton
    return GestureDetector(
      onTap: () => _open(ad),
      child: ColoredBox(
        color: const Color(0xFF0D0D0D),
        child: stacked
            ? Column(children: [
                thumb,
                texts,
                Padding(padding: const EdgeInsets.only(bottom: 8), child: button),
              ])
            : Row(children: [thumb, texts, button]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
// Tous les autres formats (17/11/2026) : carte native, affiche, carrousel, vidéo (widget AfrolookAd), plein écran et récompensée
// (AfrolookAds.showInterstitial / showRewarded). Dépendance en plus pour la vidéo : video_player.
//
//   const AfrolookAd(pubId: 'ap_xxxxxxxxxx', visitorId: monIdentifiant, format: AdsFormat.native, slot: 'liste')
//   await AfrolookAds.showInterstitial(context, pubId: 'ap_xxxxxxxxxx', visitorId: monIdentifiant);
//   await AfrolookAds.showRewarded(context, pubId: 'ap_xxxxxxxxxx', visitorId: monIdentifiant, onReward: () { /* donner la récompense */ });
// ─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

/// Formats dans le contenu.
enum AdsFormat { native, poster, carousel, video }

/// Appels au moteur, communs à tous les formats.
class _Engine {
  static Future<Map<String, dynamic>?> serve({required String apiBase, required String pubId, required String visitorId, required String fmt, required String slot, Future<Map<String, String>> Function()? headers}) async {
    try {
      final extra = headers == null ? <String, String>{} : await headers();
      final q = {'pub': pubId, 'fmt': fmt, 'slot': slot, 'vid': visitorId};
      final res = await http.get(Uri.parse('$apiBase/serve').replace(queryParameters: q), headers: extra).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final j = jsonDecode(res.body);
      final ad = j is Map ? j['ad'] : null;
      return ad is Map<String, dynamic> && ad['token'] != null ? ad : null;
    } catch (_) {
      return null;   // aucune annonce : rien ne s'affiche
    }
  }

  /// `view` quand l'annonce est restée visible pendant la durée du format ; `complete` quand une vidéo a été lue jusqu'au bout.
  static Future<void> event(Map<String, dynamic> ad, String e, String visitorId, int ms, Future<Map<String, String>> Function()? headers) async {
    try {
      final extra = headers == null ? <String, String>{} : await headers();
      await http.post(Uri.parse('${ad['event']}'), headers: {'Content-Type': 'text/plain', ...extra},
          body: jsonEncode({'t': ad['token'], 'e': e, 'ms': ms, 'vid': visitorId})).timeout(const Duration(seconds: 8));
    } catch (_) {/* tant pis : la vue n'est simplement pas comptée */}
  }

  static void open(Map<String, dynamic> ad) {
    final u = '${ad['click'] ?? ''}';
    if (u.isNotEmpty) launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication);   // le serveur compte le clic puis ouvre l'annonceur
  }

  static Map<String, dynamic> media(Map<String, dynamic> ad) => ad['media'] is Map ? Map<String, dynamic>.from(ad['media'] as Map) : const {};
  static List<String> images(Map<String, dynamic> ad) {
    final m = media(ad);
    final l = (m['images'] is List ? (m['images'] as List).map((e) => '$e') : const <String>[]).where((u) => u.startsWith('https://')).toList();
    final one = '${m['thumb'] ?? m['url'] ?? ''}';
    return l.isNotEmpty ? l : (one.startsWith('https://') ? [one] : const []);
  }
}

/// Image TOUJOURS entière, posée sur une copie floutée d'elle-même.
Widget _fitImage(String url) => Stack(fit: StackFit.expand, children: [
      ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 14, sigmaY: 14), child: Image.network(url, fit: BoxFit.cover, color: Colors.black38, colorBlendMode: BlendMode.darken, errorBuilder: (_, __, ___) => const SizedBox.shrink())),
      Image.network(url, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
    ]);

Widget _tag() => Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: const Color(0xB3000000), borderRadius: BorderRadius.circular(5)),
      child: const Text('Annonce', style: TextStyle(color: Colors.white, fontSize: 10, height: 1.3)),
    );

/// En-tête de marque : logo, nom, « Sponsorisé · domaine ».
Widget _brandRow(Map<String, dynamic> ad) {
  final b = ad['brand'] is Map ? Map<String, dynamic>.from(ad['brand'] as Map) : const <String, dynamic>{};
  final name = '${b['name'] ?? ''}';
  if (name.isEmpty) return const SizedBox.shrink();
  final logo = '${b['logo'] ?? ''}';
  final dom = '${b['domain'] ?? ''}';
  return Padding(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
    child: Row(children: [
      CircleAvatar(radius: 14, backgroundColor: const Color(0xFF2ECC71), backgroundImage: logo.startsWith('https://') ? NetworkImage(logo) : null,
          child: logo.startsWith('https://') ? null : Text(name.characters.first.toUpperCase(), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 12))),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        Text('Sponsorisé${dom.isEmpty ? '' : ' · $dom'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 11)),
      ])),
    ]),
  );
}

/// Carte native, affiche, carrousel ou vidéo dans le contenu. Rien ne s'affiche s'il n'y a pas d'annonce.
class AfrolookAd extends StatefulWidget {
  const AfrolookAd({super.key, required this.pubId, required this.visitorId, this.format = AdsFormat.native, this.slot = 'content', this.headers, this.apiBase = 'https://afrolookmedia.com/ads/api'});
  final String pubId;
  final String visitorId;
  final AdsFormat format;
  final String slot;
  final Future<Map<String, String>> Function()? headers;
  final String apiBase;

  @override
  State<AfrolookAd> createState() => _AfrolookAdState();
}

class _AfrolookAdState extends State<AfrolookAd> {
  Map<String, dynamic>? _ad;
  bool _sent = false;
  bool _done = false;
  Timer? _timer;
  VideoPlayerController? _video;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _Engine.serve(apiBase: widget.apiBase, pubId: widget.pubId, visitorId: widget.visitorId, fmt: widget.format.name, slot: widget.slot, headers: widget.headers).then((ad) {
      if (!mounted || ad == null) return;
      final m = _Engine.media(ad);
      if (widget.format == AdsFormat.video && m['type'] == 'video' && '${m['url']}'.startsWith('https://')) {
        _video = VideoPlayerController.networkUrl(Uri.parse('${m['url']}'))..setVolume(0);   // jamais de son qui démarre seul
        _video!.initialize().then((_) => mounted ? setState(() {}) : null);
        _video!.addListener(_videoEnd);
      }
      setState(() => _ad = ad);
    });
  }

  void _videoEnd() {
    final v = _video, ad = _ad;
    if (v == null || ad == null || _done || !_sent || !v.value.isInitialized) return;
    if (v.value.position >= v.value.duration - const Duration(milliseconds: 300) && v.value.duration > Duration.zero) {
      _done = true;
      _Engine.event(ad, 'complete', widget.visitorId, v.value.position.inMilliseconds, widget.headers);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _video?.removeListener(_videoEnd);
    _video?.dispose();
    super.dispose();
  }

  void _visibility(VisibilityInfo info) {
    final ad = _ad;
    if (ad == null) return;
    final visible = info.visibleFraction >= 0.5;
    final v = _video;
    if (v != null && v.value.isInitialized) visible ? v.play() : v.pause();
    if (_sent) return;
    _timer?.cancel();
    if (visible) {
      final ms = ((ad['viewMs'] as num?)?.toInt() ?? 1000) + 50;
      _timer = Timer(Duration(milliseconds: ms), () {
        if (!mounted || _sent) return;
        _sent = true;
        _Engine.event(ad, 'view', widget.visitorId, ms, widget.headers);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null) return const SizedBox.shrink();
    final imgs = _Engine.images(ad);
    final ratio = widget.format == AdsFormat.poster ? 4 / 5 : (widget.format == AdsFormat.video ? 16 / 9 : 1.91);
    Widget media;
    final v = _video;
    if (v != null && v.value.isInitialized) {
      media = AspectRatio(aspectRatio: v.value.aspectRatio, child: VideoPlayer(v));
    } else if (widget.format == AdsFormat.carousel && imgs.length > 1) {
      media = AspectRatio(aspectRatio: 1, child: Stack(children: [
        PageView(onPageChanged: (i) => setState(() => _page = i), children: [for (final u in imgs) _fitImage(u)]),
        Positioned(right: 8, bottom: 8, child: _tagText('${_page + 1}/${imgs.length}')),
      ]));
    } else {
      media = AspectRatio(aspectRatio: ratio, child: imgs.isEmpty ? const ColoredBox(color: Color(0xFF222222)) : _fitImage(imgs.first));
    }
    final text = '${ad['text'] ?? ''}';
    final cta = '${ad['cta'] ?? ''}'.isEmpty ? 'En savoir plus' : '${ad['cta']}';
    return VisibilityDetector(
      key: Key('afrolook-ad-${widget.slot}-${ad['id']}'),
      onVisibilityChanged: _visibility,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _Engine.open(ad),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _brandRow(ad),
            Padding(padding: const EdgeInsets.only(top: 10), child: Stack(children: [media, Positioned(left: 8, top: 8, child: _tag())])),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Text('${ad['title'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
            if (text.isNotEmpty && widget.format != AdsFormat.poster)
              Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Colors.grey))),
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(height: 44, child: FilledButton(onPressed: () => _Engine.open(ad), child: Text(cta))),   // bouton d'au moins 44 px
            ),
          ]),
        ),
      ),
    );
  }
}

Widget _tagText(String t) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: const Color(0xB3000000), borderRadius: BorderRadius.circular(99)),
      child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 11)),
    );

/// Plein écran et récompensée.
class AfrolookAds {
  AfrolookAds._();

  /// Plein écran entre deux écrans : croix active au bout de 3 secondes. Renvoie faux s'il n'y avait pas d'annonce.
  static Future<bool> showInterstitial(BuildContext context, {required String pubId, required String visitorId, String slot = 'interstitial', Future<Map<String, String>> Function()? headers, String apiBase = 'https://afrolookmedia.com/ads/api'}) async {
    final ad = await _Engine.serve(apiBase: apiBase, pubId: pubId, visitorId: visitorId, fmt: 'interstitial', slot: slot, headers: headers);
    if (ad == null || !context.mounted) return false;
    await showGeneralDialog(context: context, barrierDismissible: false, barrierColor: Colors.black87, pageBuilder: (_, __, ___) => _FullAd(ad: ad, visitorId: visitorId, headers: headers, rewarded: false));
    return true;
  }

  /// Récompensée : la personne choisit de regarder ; [onReward] n'est appelé qu'après la lecture COMPLÈTE de la vidéo. Renvoie vrai si la récompense est due.
  static Future<bool> showRewarded(BuildContext context, {required String pubId, required String visitorId, required VoidCallback onReward, String slot = 'rewarded', Future<Map<String, String>> Function()? headers, String apiBase = 'https://afrolookmedia.com/ads/api'}) async {
    final ad = await _Engine.serve(apiBase: apiBase, pubId: pubId, visitorId: visitorId, fmt: 'rewarded', slot: slot, headers: headers);
    if (ad == null || !context.mounted) return false;
    final ok = await showGeneralDialog<bool>(context: context, barrierDismissible: false, barrierColor: Colors.black, pageBuilder: (_, __, ___) => _FullAd(ad: ad, visitorId: visitorId, headers: headers, rewarded: true));
    if (ok == true) onReward();
    return ok == true;
  }
}

class _FullAd extends StatefulWidget {
  const _FullAd({required this.ad, required this.visitorId, required this.headers, required this.rewarded});
  final Map<String, dynamic> ad;
  final String visitorId;
  final Future<Map<String, String>> Function()? headers;
  final bool rewarded;

  @override
  State<_FullAd> createState() => _FullAdState();
}

class _FullAdState extends State<_FullAd> {
  VideoPlayerController? _video;
  Timer? _view;
  Timer? _tick;
  int _wait = 3;
  bool _complete = false;

  @override
  void initState() {
    super.initState();
    final m = _Engine.media(widget.ad);
    if (m['type'] == 'video' && '${m['url']}'.startsWith('https://')) {
      _video = VideoPlayerController.networkUrl(Uri.parse('${m['url']}'));
      _video!.initialize().then((_) { if (mounted) { setState(() {}); _video!.play(); } });
      _video!.addListener(_onVideo);
    }
    final ms = ((widget.ad['viewMs'] as num?)?.toInt() ?? 1000) + 50;
    _view = Timer(Duration(milliseconds: ms), () => _Engine.event(widget.ad, 'view', widget.visitorId, ms, widget.headers));
    if (!widget.rewarded) {
      _tick = Timer.periodic(const Duration(seconds: 1), (t) { if (!mounted) return; setState(() => _wait--); if (_wait <= 0) t.cancel(); });
    }
  }

  void _onVideo() {
    final v = _video;
    if (v == null || _complete || !v.value.isInitialized || v.value.duration == Duration.zero) return;
    if (v.value.position >= v.value.duration - const Duration(milliseconds: 300)) {
      _complete = true;
      _Engine.event(widget.ad, 'complete', widget.visitorId, v.value.position.inMilliseconds, widget.headers);
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _view?.cancel();
    _tick?.cancel();
    _video?.removeListener(_onVideo);
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = widget.ad, v = _video, imgs = _Engine.images(ad);
    final canClose = widget.rewarded ? true : _wait <= 0;
    final cta = '${ad['cta'] ?? ''}'.isEmpty ? 'En savoir plus' : '${ad['cta']}';
    return Material(
      color: Colors.black,
      child: SafeArea(
        child: Stack(children: [
          Positioned.fill(child: v != null && v.value.isInitialized
              ? Center(child: AspectRatio(aspectRatio: v.value.aspectRatio, child: VideoPlayer(v)))
              : (imgs.isEmpty ? const SizedBox.shrink() : _fitImage(imgs.first))),
          Positioned(left: 12, top: 12, child: _tag()),
          Positioned(right: 8, top: 8, child: IconButton.filled(
            onPressed: canClose ? () => Navigator.of(context).pop(widget.rewarded && _complete) : null,
            icon: canClose ? const Icon(Icons.close) : Text('$_wait'),
            tooltip: widget.rewarded && !_complete ? 'Fermer sans la récompense' : 'Fermer',
          )),
          Positioned(left: 16, right: 16, bottom: 16, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            if (widget.rewarded)
              Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_complete ? 'Récompense gagnée : tu peux fermer.' : 'Regarde la vidéo jusqu’au bout pour obtenir ta récompense.',
                  textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 13))),
            Text('${ad['title'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 10),
            SizedBox(height: 48, child: FilledButton(onPressed: () => _Engine.open(ad), child: Text(cta))),
          ])),
        ]),
      ),
    );
  }
}
