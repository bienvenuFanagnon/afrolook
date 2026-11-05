import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/services/api/regie_api.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'ad_actions.dart';

/// Composants d'annonce d'Afrolook : reproduction EXACTE de la maquette validée le 05/11 (`docs/maquette_pub_app/`) :
///  A image · B vidéo · G plusieurs images (BrandAdCard) · C page de détails (AdDetailPage) · D boost d'un membre (MemberBoostCard)
///  E petite annonce (BrandAdCompact) · F bannière (BrandBanner) · H boost d'un profil, canal ou groupe (EntityBoostCard).
/// Règles : la MARQUE et son logo (jamais un profil ni « Suivre ») pour une annonce venue du site ; « Sponsorisé » toujours écrit ; un bouton d'action jaune sur chaque annonce.

/// Annonce d'Afrolook Ads venue du SITE : portée par une « publication » synthétique (identifiant `ad_…`, voir `AfrolookAdsPool`).
bool isBrandPost(Post? post) => (post?.id ?? '').startsWith('ad_');

String brandNameOf(Advertisement ad) => (ad.ownerName ?? '').trim().isNotEmpty ? ad.ownerName!.trim() : 'Afrolook Ads';

String _host(Advertisement ad) {
  final host = Uri.tryParse((ad.actionUrl ?? '').trim())?.host ?? '';
  return host.startsWith('www.') ? host.substring(4) : host;
}

bool _isStore(String h) => h == 'play.google.com' || h == 'apps.apple.com' || h == 'itunes.apple.com';

/// Ligne « domaine » de la barre d'action : le site, ou le nom de la boutique d'applications / de la messagerie.
String brandDomainOf(Advertisement ad) {
  final h = _host(ad);
  if (h == 'play.google.com') return 'Google Play';
  if (h == 'apps.apple.com' || h == 'itunes.apple.com') return 'App Store';
  if (h == 'wa.me' || h.endsWith('whatsapp.com')) return 'WhatsApp';
  if (h == 't.me') return 'Telegram';
  return h;
}

/// Texte à droite de « Sponsorisé » : « Application » pour une boutique d'applications, sinon la ville de la marque.
String _subLine(Advertisement ad) => switch (ad.adType) {
      'app' => 'Application',
      'whatsapp' => 'WhatsApp',
      'call' => 'Appel',
      'event' => 'Événement',
      'social' => 'Page',
      _ => _isStore(_host(ad)) ? 'Application' : (ad.brandCity ?? '').trim(),
    };

/// Prix d'un produit (« 12 500 F CFA »), seulement pour une annonce « Produit » dont le prix est connu ; sinon rien : jamais de prix inventé.
String? adPriceLabel(Advertisement ad) {
  final p = ad.productPrice ?? 0;
  if (ad.adType != 'product' || p <= 0) return null;
  final s = p.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('\u202F');
    b.write(s[i]);
  }
  return '$b F CFA';
}

/// Libellé du bouton choisi par l'annonceur (Visiter le site, Installer, Appeler…), à défaut celui du type d'action.
String adButtonLabel(Advertisement ad) => (ad.actionButtonText ?? '').trim().isNotEmpty ? ad.actionButtonText!.trim() : ad.getActionButtonText();

const _jaune = Color(0xFFFFC400);
const _texteSurJaune = Color(0xFF20260F);
const _vert = Color(0xFF0F7B43);
const _ligneClair = Color(0xFFE3E8E4);
const _barreClair = Color(0xFFF6F8F6);

class _Pal {
  _Pal(BuildContext c) : dark = Theme.of(c).brightness == Brightness.dark;
  final bool dark;
  Color get card => dark ? const Color(0xFF1A1A1A) : Colors.white;
  Color get line => dark ? Colors.white12 : _ligneClair;
  Color get bar => dark ? Colors.white10 : _barreClair;
  Color get text => dark ? Colors.white : const Color(0xFF14201A);
  Color get sub => dark ? const Color(0xFFAAB3AC) : const Color(0xFF6B766F);
  Color get media => dark ? Colors.white10 : const Color(0xFFEFF2EF);
}

String? _firstVisual(Post post) {
  if ((post.thumbnail ?? '').isNotEmpty) return post.thumbnail;
  final imgs = post.images ?? const <String>[];
  if (imgs.isNotEmpty) return imgs.first;
  if (post.dataType != PostDataType.VIDEO.name && (post.url_media ?? '').isNotEmpty) return post.url_media;
  return null;
}

bool _isVideo(Post post) => post.dataType == PostDataType.VIDEO.name || (post.url_media ?? '').contains('.mp4') || (post.url_media ?? '').contains('.mov');

String _mmss(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

/// Logo rond de la marque (initiale sur fond vert si pas de logo).
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, required this.name, this.url, this.size = 38});
  final String name;
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? 'A' : name.trim().characters.first.toUpperCase();
    final fallback = Container(width: size, height: size, alignment: Alignment.center, color: _vert, child: Text(initial, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * .42, decoration: TextDecoration.none)));
    return ClipOval(
      child: (url ?? '').startsWith('http')
          ? CachedNetworkImage(imageUrl: url!, width: size, height: size, fit: BoxFit.cover, placeholder: (_, __) => fallback, errorWidget: (_, __, ___) => fallback)
          : fallback,
    );
  }
}

/// Étiquette grise « Sponsorisé » (ou « Annonce »).
class SponsoredTag extends StatelessWidget {
  const SponsoredTag({super.key, this.label = 'Sponsorisé'});
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = _Pal(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(color: p.dark ? Colors.white12 : const Color(0xFFF1F3F1), border: Border.all(color: p.line), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, height: 1.5, color: p.dark ? Colors.white70 : const Color(0xFF445044), decoration: TextDecoration.none)),
    );
  }
}

/// Bouton jaune (fond jaune, texte sombre). `size` : normal (barre d'action), mini (petites annonces), big (pleine largeur).
enum AdBtnSize { mini, normal, big }

class AdYellowButton extends StatelessWidget {
  const AdYellowButton({super.key, required this.label, required this.onTap, this.size = AdBtnSize.normal, this.green = false});
  final String label;
  final VoidCallback onTap;
  final AdBtnSize size;
  final bool green;

  @override
  Widget build(BuildContext context) {
    final big = size == AdBtnSize.big, mini = size == AdBtnSize.mini;
    final r = BorderRadius.circular(big ? 14 : (mini ? 8 : 10));
    return Material(
      color: green ? _vert : _jaune,
      borderRadius: r,
      child: InkWell(
        borderRadius: r,
        onTap: onTap,
        child: Padding(
          padding: big ? const EdgeInsets.symmetric(vertical: 14, horizontal: 16) : (mini ? const EdgeInsets.symmetric(horizontal: 10, vertical: 5) : const EdgeInsets.symmetric(horizontal: 14, vertical: 9)),
          child: Row(mainAxisSize: big ? MainAxisSize.max : MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: green ? Colors.white : _texteSurJaune, fontWeight: FontWeight.w800, fontSize: big ? 17 : (mini ? 12 : 14), decoration: TextDecoration.none))),
          ]),
        ),
      ),
    );
  }
}

/// Menu « ⋯ » d'une annonce : « Pourquoi cette annonce ? » et « Signaler ».
class AdMenuButton extends StatelessWidget {
  const AdMenuButton({super.key, required this.ad});
  final Advertisement ad;

  @override
  Widget build(BuildContext context) {
    final p = _Pal(context);
    return IconButton(visualDensity: VisualDensity.compact, icon: Icon(Icons.more_horiz, color: p.sub), tooltip: 'Plus', onPressed: () => showAdMenu(context, ad));
  }
}

void showAdMenu(BuildContext context, Advertisement ad) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.info_outline), title: const Text('Pourquoi cette annonce ?'), onTap: () { Navigator.pop(sheet); showWhyThisAd(context); }),
        ListTile(leading: const Icon(Icons.flag_outlined), title: const Text('Signaler cette annonce'), onTap: () { Navigator.pop(sheet); showReportAd(context, ad); }),
        const SizedBox(height: 8),
      ]),
    ),
  );
}

void showWhyThisAd(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => const SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Pourquoi cette annonce ?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          SizedBox(height: 10),
          Text('C\'est une annonce diffusée par Afrolook Ads. Elle t\'est montrée selon ton pays, ta langue et ce que tu aimes sur Afrolook.', style: TextStyle(fontSize: 15, height: 1.4)),
        ]),
      ),
    ),
  );
}

const _motifs = <String, String>{'misleading': 'Trompeuse', 'scam': 'Arnaque', 'offensive': 'Choquante', 'irrelevant': 'Sans intérêt pour moi', 'other': 'Autre motif'};

void showReportAd(BuildContext context, Advertisement ad) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(padding: EdgeInsets.fromLTRB(20, 0, 20, 8), child: Text('Signaler cette annonce', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
        for (final e in _motifs.entries)
          ListTile(
            title: Text(e.value),
            onTap: () async {
              Navigator.pop(sheet);
              String msg = 'Merci, nous allons examiner cette annonce.';
              try {
                if (ad.id != null) await RegieApi.post('/ads/app/report', body: {'ad': ad.id, 'reason': e.key});
              } catch (_) {
                msg = 'Le signalement n\'a pas pu être envoyé. Réessaie dans un instant.';
              }
              messenger?.showSnackBar(SnackBar(content: Text(msg)));
            },
          ),
        const SizedBox(height: 8),
      ]),
    ),
  );
}

/// En-tête commun : logo, nom, « Sponsorisé · <ville> », et à droite ce qu'on veut (menu ⋯ ou bouton Suivre).
class _Header extends StatelessWidget {
  const _Header({required this.name, required this.logoUrl, required this.sub, this.trailing});
  final String name;
  final String? logoUrl;
  final String sub;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = _Pal(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 10, trailing is IconButton || trailing is AdMenuButton ? 4 : 12, 10),
      child: Row(children: [
        BrandLogo(name: name, url: logoUrl),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, height: 1.1, color: p.text, decoration: TextDecoration.none)),
            const SizedBox(height: 2),
            Row(children: [
              const SponsoredTag(),
              if (sub.isNotEmpty) ...[const SizedBox(width: 6), Flexible(child: Text('· $sub', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: p.sub, decoration: TextDecoration.none)))],
            ]),
          ]),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ]),
    );
  }
}

/// Barre d'action sous le visuel : domaine (petit) au-dessus du titre (gras), bouton jaune à droite.
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.domain, required this.title, required this.label, required this.onTap, this.price});
  final String domain;
  final String? price;
  final String title;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = _Pal(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(color: p.bar, border: Border(top: BorderSide(color: p.line))),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            if (domain.isNotEmpty) Text(domain, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, height: 1.2, color: p.sub, decoration: TextDecoration.none)),
            if (title.isNotEmpty) Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, height: 1.15, color: p.text, decoration: TextDecoration.none)),
            if (price != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(price!, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, height: 1.2, color: p.text, decoration: TextDecoration.none))),
          ]),
        ),
        const SizedBox(width: 10),
        AdYellowButton(label: label, onTap: onTap),
      ]),
    );
  }
}

BoxDecoration _cardDeco(_Pal p) => BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: p.line));

/// A (image), B (vidéo), G (plusieurs images) : annonce d'un annonceur du site dans le fil.
class BrandAdCard extends StatefulWidget {
  const BrandAdCard({super.key, required this.ad, required this.post, required this.onOpenDetails, required this.onAction, this.videoController});
  final Advertisement ad;
  final Post post;
  final VoidCallback onOpenDetails;
  final VoidCallback onAction;

  /// Vidéo déjà prête (muette, en boucle) : montrée à la place de la vignette, avec barre de progression et bouton de son.
  final VideoPlayerController? videoController;

  @override
  State<BrandAdCard> createState() => _BrandAdCardState();
}

class _BrandAdCardState extends State<BrandAdCard> {
  int _page = 0;
  bool _muted = true;

  @override
  Widget build(BuildContext context) {
    final p = _Pal(context);
    final ad = widget.ad, post = widget.post;
    final name = brandNameOf(ad), caption = (post.description ?? ad.description ?? '').trim();
    final video = _isVideo(post);
    final images = (post.images ?? const <String>[]).where((u) => u.isNotEmpty).toList();
    final carousel = !video && images.length > 1;
    final visual = _firstVisual(post);
    final vc = widget.videoController;
    final ready = vc != null && vc.value.isInitialized;
    final secs = ad.videoSeconds ?? (ready ? vc.value.duration.inSeconds : 0);

    Widget media;
    if (ready) {
      media = FittedBox(fit: BoxFit.cover, clipBehavior: Clip.hardEdge, child: SizedBox(width: vc.value.size.width, height: vc.value.size.height, child: VideoPlayer(vc)));
    } else if (carousel) {
      media = PageView(onPageChanged: (i) => setState(() => _page = i), children: [for (final u in images) CachedNetworkImage(imageUrl: u, fit: BoxFit.cover, errorWidget: (_, __, ___) => Container(color: p.media))]);
    } else if (visual != null) {
      media = CachedNetworkImage(imageUrl: visual, fit: BoxFit.cover, placeholder: (_, __) => const SizedBox.shrink(), errorWidget: (_, __, ___) => Icon(Icons.image, color: p.sub, size: 48));
    } else {
      media = Center(child: Icon(Icons.campaign_rounded, color: p.sub, size: 56));
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: _cardDeco(p),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        _Header(name: name, logoUrl: ad.ownerAvatar, sub: _subLine(ad), trailing: AdMenuButton(ad: ad)),
        GestureDetector(
          onTap: widget.onOpenDetails,
          child: AspectRatio(
            aspectRatio: video ? 4 / 5 : 1,
            child: Stack(fit: StackFit.expand, children: [
              Container(color: p.media),
              media,
              if (video && !ready) Center(child: Container(width: 58, height: 58, decoration: const BoxDecoration(color: Color(0x80000000), shape: BoxShape.circle), child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32))),
              if (video && secs > 0) Positioned(left: 10, bottom: 14, child: Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3), decoration: BoxDecoration(color: const Color(0x8C000000), borderRadius: BorderRadius.circular(12)), child: Text(_mmss(secs), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700, decoration: TextDecoration.none)))),
              if (video) Positioned(right: 10, bottom: 14, child: GestureDetector(onTap: () { if (ready) { setState(() { _muted = !_muted; vc.setVolume(_muted ? 0 : 1); }); } else { widget.onOpenDetails(); } }, child: Container(width: 30, height: 30, decoration: const BoxDecoration(color: Color(0x8C000000), shape: BoxShape.circle), child: Icon(_muted ? Icons.volume_off : Icons.volume_up, color: Colors.white, size: 16)))),
              if (video) Positioned(left: 0, right: 0, bottom: 0, child: ready ? VideoProgressIndicator(vc, allowScrubbing: false, padding: EdgeInsets.zero, colors: const VideoProgressColors(playedColor: _jaune, bufferedColor: Colors.white30, backgroundColor: Colors.white24)) : const SizedBox(height: 4, child: LinearProgressIndicator(value: 0, backgroundColor: Colors.white24, color: _jaune))),
              if (carousel) Positioned(right: 10, top: 10, child: Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3), decoration: BoxDecoration(color: const Color(0x8C000000), borderRadius: BorderRadius.circular(12)), child: Text('${_page + 1}/${images.length}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700, decoration: TextDecoration.none)))),
            ]),
          ),
        ),
        if (carousel)
          Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [for (var i = 0; i < images.length; i++) Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: Container(width: 9, height: 9, decoration: BoxDecoration(shape: BoxShape.circle, color: i == _page ? _vert : Colors.transparent, border: Border.all(color: _vert, width: 1.6))))]))),
        if ((ad.actionUrl ?? '').isNotEmpty) _ActionBar(domain: brandDomainOf(ad), price: adPriceLabel(ad), title: (ad.adTitle ?? '').trim(), label: adButtonLabel(ad), onTap: widget.onAction),
        if (caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Text.rich(TextSpan(children: [TextSpan(text: '$name ', style: const TextStyle(fontWeight: FontWeight.w800)), TextSpan(text: caption)]), maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, height: 1.35, color: p.text, decoration: TextDecoration.none)),
          ),
      ]),
    );
  }
}

/// D : boost d'une publication d'un membre (le profil existe : avatar, pseudo, abonnés, « Suivre »).
class MemberBoostCard extends StatelessWidget {
  const MemberBoostCard({super.key, required this.ad, required this.post, required this.onOpenPost, required this.onFollow, this.videoController});
  final Advertisement ad;
  final Post post;
  final VoidCallback onOpenPost;
  final VoidCallback onFollow;
  final VideoPlayerController? videoController;

  @override
  Widget build(BuildContext context) {
    final p = _Pal(context);
    final name = (ad.ownerName ?? '').isEmpty ? 'Afrolook' : (ad.ownerName!.startsWith('@') ? ad.ownerName! : '@${ad.ownerName}');
    final followers = ad.ownerFollowers;
    final visual = _firstVisual(post), vc = videoController, ready = vc != null && vc.value.isInitialized;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: _cardDeco(p),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        _Header(name: name, logoUrl: ad.ownerAvatar, sub: followers == null ? '' : '$followers abonnés', trailing: AdYellowButton(label: 'Suivre', onTap: onFollow)),
        GestureDetector(
          onTap: onOpenPost,
          child: AspectRatio(
            aspectRatio: 1,
            child: Stack(fit: StackFit.expand, children: [
              Container(color: p.media),
              if (ready) FittedBox(fit: BoxFit.cover, clipBehavior: Clip.hardEdge, child: SizedBox(width: vc.value.size.width, height: vc.value.size.height, child: VideoPlayer(vc)))
              else if (visual != null) CachedNetworkImage(imageUrl: visual, fit: BoxFit.cover, errorWidget: (_, __, ___) => Icon(Icons.image, color: p.sub, size: 48))
              else Center(child: Icon(Icons.image, color: p.sub, size: 48)),
              if (_isVideo(post) && !ready) Center(child: Container(width: 58, height: 58, decoration: const BoxDecoration(color: Color(0x80000000), shape: BoxShape.circle), child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32))),
            ]),
          ),
        ),
        _ActionBar(domain: '', title: 'Voir la publication', label: 'Ouvrir', onTap: onOpenPost),
      ]),
    );
  }
}

/// E : petite annonce (commentaires, listes, conversations, groupes, musique) : vignette, marque, « Sponsorisé · secteur », petit bouton.
class BrandAdCompact extends StatelessWidget {
  const BrandAdCompact({super.key, required this.ad, required this.post, required this.onOpenDetails, required this.onAction});
  final Advertisement ad;
  final Post post;
  final VoidCallback onOpenDetails;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final p = _Pal(context);
    final name = brandNameOf(ad), visual = _firstVisual(post), hasAction = (ad.actionUrl ?? '').isNotEmpty;
    final sector = adPriceLabel(ad) ?? ((ad.brandSector ?? '').trim().isNotEmpty ? ad.brandSector!.trim() : brandDomainOf(ad));
    return GestureDetector(
      onTap: onOpenDetails,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        padding: const EdgeInsets.all(10),
        decoration: _cardDeco(p),
        child: Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(width: 64, height: 64, child: visual != null ? CachedNetworkImage(imageUrl: visual, fit: BoxFit.cover, errorWidget: (_, __, ___) => Container(color: p.media)) : Container(color: p.media, child: Icon(Icons.campaign_rounded, color: p.sub)))),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, height: 1.2, color: p.text, decoration: TextDecoration.none)),
              const SizedBox(height: 2),
              Row(children: [const SponsoredTag(), if (sector.isNotEmpty) ...[const SizedBox(width: 6), Flexible(child: Text(sector, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: p.sub, decoration: TextDecoration.none)))]]),
              if (hasAction) Padding(padding: const EdgeInsets.only(top: 6), child: AdYellowButton(label: adButtonLabel(ad), onTap: onAction, size: AdBtnSize.mini)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// F : bannière (détail d'une publication, musique, groupes) : visuel avec étiquette « Annonce » et nom de la marque, barre d'action dessous.
class BrandBanner extends StatelessWidget {
  const BrandBanner({super.key, required this.ad, required this.post, required this.onOpenDetails, required this.onAction});
  final Advertisement ad;
  final Post post;
  final VoidCallback onOpenDetails;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final p = _Pal(context);
    final name = brandNameOf(ad), visual = _firstVisual(post);
    final title = (ad.adTitle ?? '').trim().isNotEmpty ? ad.adTitle!.trim() : (post.description ?? ad.description ?? '').trim();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: _cardDeco(p),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        GestureDetector(
          onTap: onOpenDetails,
          child: SizedBox(
            height: 120,
            child: Stack(fit: StackFit.expand, children: [
              Container(color: _vert),
              if (visual != null) CachedNetworkImage(imageUrl: visual, fit: BoxFit.cover, errorWidget: (_, __, ___) => const SizedBox.shrink()),
              Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [Color(0xCC0B5A33), Color(0x330B5A33)]))),
              Positioned(left: 16, right: 80, top: 0, bottom: 0, child: Align(alignment: Alignment.centerLeft, child: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, height: 1.15, shadows: [Shadow(color: Colors.black38, blurRadius: 6)], decoration: TextDecoration.none)))),
              const Positioned(right: 8, top: 8, child: SponsoredTag(label: 'Annonce')),
            ]),
          ),
        ),
        if ((ad.actionUrl ?? '').isNotEmpty) _ActionBar(domain: '', title: title, label: adButtonLabel(ad), onTap: onAction),
      ]),
    );
  }
}

/// H : boost d'un profil, d'un canal ou d'un groupe (compte qui existe dans Afrolook) : carte centrée, grand avatar, bouton vert.
class EntityBoostCard extends StatelessWidget {
  const EntityBoostCard({super.key, required this.ad, required this.followers, required this.onOpen});
  final Advertisement ad;
  final int? followers;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final p = _Pal(context);
    final type = ad.ownerType;
    final kind = type == 'canal' ? 'Canal' : (type == 'group' ? 'Groupe' : 'Créateur');
    final unit = type == 'group' ? 'membres' : 'abonnés';
    final label = type == 'canal' ? 'Rejoindre le canal' : (type == 'group' ? 'Rejoindre le groupe' : 'Suivre');
    final n = followers ?? ad.ownerFollowers;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(p),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SponsoredTag(),
        const SizedBox(height: 14),
        BrandLogo(name: ad.ownerName ?? '', url: ad.ownerAvatar, size: 84),
        const SizedBox(height: 8),
        Text(ad.ownerName ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: p.text, decoration: TextDecoration.none)),
        const SizedBox(height: 4),
        Text(n == null ? kind : '$kind · $n $unit', style: TextStyle(fontSize: 14, color: p.sub, decoration: TextDecoration.none)),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: AdYellowButton(label: label, onTap: onOpen, size: AdBtnSize.big, green: true)),
      ]),
    );
  }
}

/// Marque + « Sponsorisé » sur fond sombre (vidéo plein écran, chroniques).
class BrandOverlayHeader extends StatelessWidget {
  const BrandOverlayHeader({super.key, required this.ad});
  final Advertisement ad;

  @override
  Widget build(BuildContext context) {
    final name = brandNameOf(ad), domain = brandDomainOf(ad);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      BrandLogo(name: name, url: ad.ownerAvatar, size: 36),
      const SizedBox(width: 10),
      Flexible(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800, shadows: [Shadow(color: Colors.black54, blurRadius: 6)], decoration: TextDecoration.none)),
          Text(domain.isNotEmpty ? 'Sponsorisé · $domain' : 'Sponsorisé', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12, shadows: [Shadow(color: Colors.black54, blurRadius: 6)], decoration: TextDecoration.none)),
        ]),
      ),
    ]);
  }
}

/// C : page de détails de l'annonce : visuel, marque, titre, texte, « Pourquoi cette annonce ? · Signaler », bouton d'action TOUJOURS visible en bas.
class AdDetailPage extends StatefulWidget {
  const AdDetailPage({super.key, required this.ad, required this.post, this.onAction});
  final Advertisement ad;
  final Post post;
  final VoidCallback? onAction;

  @override
  State<AdDetailPage> createState() => _AdDetailPageState();
}

class _AdDetailPageState extends State<AdDetailPage> {
  VideoPlayerController? _video;
  bool _muted = true;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    final p = widget.post;
    if (_isVideo(p) && (p.url_media ?? '').startsWith('http')) {
      final c = VideoPlayerController.networkUrl(Uri.parse(p.url_media!));
      _video = c;
      c.initialize().then((_) {
        if (!mounted) return;
        c.setVolume(0);
        c.setLooping(true);
        c.play();
        setState(() {});
      }).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    widget.onAction?.call();
    await AdActions.open(widget.ad);
  }

  @override
  Widget build(BuildContext context) {
    final p = _Pal(context);
    final ad = widget.ad, post = widget.post, name = brandNameOf(ad), domain = brandDomainOf(ad);
    final images = (post.images ?? const <String>[]).where((u) => u.isNotEmpty).toList();
    final visual = _firstVisual(post);
    final hasAction = (ad.actionUrl ?? '').isNotEmpty;
    final title = (ad.adTitle ?? '').trim(), desc = (post.description ?? ad.description ?? '').trim();

    Widget media;
    if (_video != null && _video!.value.isInitialized) {
      media = Stack(alignment: Alignment.bottomRight, children: [
        AspectRatio(aspectRatio: _video!.value.aspectRatio, child: VideoPlayer(_video!)),
        Padding(padding: const EdgeInsets.all(10), child: GestureDetector(onTap: () => setState(() { _muted = !_muted; _video!.setVolume(_muted ? 0 : 1); }), child: Container(width: 34, height: 34, decoration: const BoxDecoration(color: Color(0x8C000000), shape: BoxShape.circle), child: Icon(_muted ? Icons.volume_off : Icons.volume_up, color: Colors.white, size: 18)))),
      ]);
    } else if (images.length > 1) {
      media = AspectRatio(aspectRatio: 1, child: Stack(children: [
        PageView(onPageChanged: (i) => setState(() => _page = i), children: [for (final u in images) CachedNetworkImage(imageUrl: u, fit: BoxFit.cover, width: double.infinity)]),
        Positioned(right: 10, top: 10, child: Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3), decoration: BoxDecoration(color: const Color(0x8C000000), borderRadius: BorderRadius.circular(12)), child: Text('${_page + 1}/${images.length}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)))),
      ]));
    } else if (visual != null) {
      media = AspectRatio(aspectRatio: 1, child: CachedNetworkImage(imageUrl: visual, fit: BoxFit.cover, width: double.infinity, errorWidget: (_, __, ___) => Container(color: p.media)));
    } else {
      media = Container(height: 200, color: p.media, child: Center(child: Icon(Icons.campaign_rounded, color: p.sub, size: 56)));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Annonce', style: TextStyle(fontWeight: FontWeight.w800)), actions: [AdMenuButton(ad: ad)]),
      body: ListView(padding: EdgeInsets.zero, children: [
        media,
        Container(
          color: p.card,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              BrandLogo(name: name, url: ad.ownerAvatar),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: p.text)),
                const SizedBox(height: 2),
                Row(children: [const SponsoredTag(), if (domain.isNotEmpty) ...[const SizedBox(width: 6), Flexible(child: Text('· $domain', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: p.sub)))]]),
              ])),
            ]),
            if (title.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(title, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, height: 1.25, color: p.text))),
            if (adPriceLabel(ad) != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(adPriceLabel(ad)!, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: p.text))),
            if (desc.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(desc, style: TextStyle(fontSize: 15, height: 1.4, color: p.dark ? Colors.white70 : const Color(0xFF33403A)))),
            const SizedBox(height: 14),
            Row(children: [
              GestureDetector(onTap: () => showWhyThisAd(context), child: Text('ⓘ Pourquoi cette annonce ?', style: TextStyle(fontSize: 13, color: p.sub))),
              Text(' · ', style: TextStyle(fontSize: 13, color: p.sub)),
              GestureDetector(onTap: () => showReportAd(context, ad), child: Text('⚑ Signaler', style: TextStyle(fontSize: 13, color: p.sub))),
            ]),
          ]),
        ),
      ]),
      bottomNavigationBar: hasAction
          ? Container(
              decoration: BoxDecoration(color: p.card, border: Border(top: BorderSide(color: p.line))),
              child: SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(12, 10, 12, 14), child: AdYellowButton(label: adButtonLabel(ad), onTap: _open, size: AdBtnSize.big))),
            )
          : null,
    );
  }
}
