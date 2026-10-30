// Composant prêt à l'emploi d'Afrolook Ads : bannières d'applications (mini bannière du bas, grande bannière, rectangle moyen, leaderboard).
// Même fichier pour nos applications et pour les diffuseurs (copie publiée sur https://afrolookmedia.com/ads/afrolook_ads_banner.dart).
//
// Dépendances : http, url_launcher, visibility_detector.
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

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
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

  /// Valeur du paramètre `size` d'adsServe.
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
    this.apiBase = 'https://us-central1-afrolooki.cloudfunctions.net',
  });

  /// Mini bannière fixe en bas d'un écran : 320 × 50, fermable, centrée, avec la marge de sécurité de l'écran.
  const AfrolookAdsBanner.bottom({
    super.key,
    required this.pubId,
    required this.visitorId,
    this.slot = 'bottom',
    this.refresh = const Duration(seconds: 60),
    this.headers,
    this.apiBase = 'https://us-central1-afrolooki.cloudfunctions.net',
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
      final res = await http.get(Uri.parse('${widget.apiBase}/adsServe').replace(queryParameters: q), headers: extra).timeout(const Duration(seconds: 8));
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
