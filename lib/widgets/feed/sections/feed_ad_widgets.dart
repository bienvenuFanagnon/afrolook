import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../pages/admin/AfrolookPub/advertisementCarouselWidget.dart';
import '../../../pages/pub/banner_ad_widget.dart';
import '../../../pages/pub/native_ad_widget.dart';
import '../../../providers/authProvider.dart';

/// Bannière publicitaire (petit format).
class FeedAdBanner extends StatelessWidget {
  final String adKey;
  const FeedAdBanner({Key? key, required this.adKey}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey(adKey),
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: BannerAdWidget(
        onAdLoaded: () {},
      ),
    );
  }
}

/// Publicité format rectangle moyen (MREC — 300×250).
/// La hauteur est explicitement contrainte pour éviter que Google Ads reçoive
/// des contraintes nulles (cause du crash _RenderDeferredLayoutBox).
class FeedAdMrec extends StatelessWidget {
  final String adKey;
  const FeedAdMrec({Key? key, required this.adKey}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey(adKey),
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      height: 260,
      alignment: Alignment.center,
      child: MrecAdWidget(
        key: ValueKey(adKey),
        onAdLoaded: () {},
      ),
    );
  }
}

/// Carrousel de publicités Afrolook — s'affiche comme un post normal dans le feed
/// (image + stats + boutons d'action + extras pub), avec une bordure de séparation.
class FeedAdCarousel extends StatelessWidget {
  final String adKey;
  const FeedAdCarousel({Key? key, required this.adKey}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    const hMargin = 12.0;
    final cardWidth = screenWidth - hMargin * 2;
    // Hauteur de la partie image uniquement (4:5, format feed agréable).
    // Le widget total sera plus haut car il inclut les stats et boutons.
    final imageHeight = cardWidth * 0.85;

    return Container(
      key: ValueKey(adKey),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: hMargin),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: AdvertisementCarouselWidget(
        height: imageHeight,
        width: cardWidth,
        showIndicators: true,
      ),
    );
  }
}

/// Slot pub unifié : affiche le carousel Afrolook si des posts boostés existent,
/// sinon affiche le MRec Google Ads. Jamais les deux ensemble.
class FeedUnifiedAdSlot extends StatelessWidget {
  final String adKey;
  const FeedUnifiedAdSlot({Key? key, required this.adKey}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<UserAuthProvider>(
      builder: (context, auth, _) {
        final hasBoostedPosts = auth.advertisements
            .any((a) => a['isEntityBoost'] != true && a['post'] != null);
        if (hasBoostedPosts) {
          return FeedAdCarousel(adKey: adKey);
        }
        return FeedAdMrec(adKey: adKey);
      },
    );
  }
}

/// Wrapper de slot pool rotatif : affiche [poolChild] si il a du contenu,
/// sinon bascule sur [FeedUnifiedAdSlot] après vérification post-frame.
/// Donne 800 ms aux widgets async (streams Firestore) pour charger leurs données
/// avant de décider qu'ils sont vides.
class FeedPoolOrAd extends StatefulWidget {
  final Widget poolChild;
  final String adKey;
  const FeedPoolOrAd({Key? key, required this.poolChild, required this.adKey})
      : super(key: key);

  @override
  State<FeedPoolOrAd> createState() => _FeedPoolOrAdState();
}

class _FeedPoolOrAdState extends State<FeedPoolOrAd> {
  final GlobalKey _key = GlobalKey();
  bool _useAd = false;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    // Premier check rapide (frame suivante) — widgets sync déjà rendus
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAfterDelay(0));
    // Deuxième check après 800 ms — laisse le temps aux streams Firestore
    Future.delayed(const Duration(milliseconds: 800), () => _checkAfterDelay(1));
  }

  void _checkAfterDelay(int pass) {
    if (!mounted || _checked) return;
    final ctx = _key.currentContext;
    final box = ctx?.findRenderObject() as RenderBox?;
    final isEmpty = box == null || !box.hasSize || box.size.height < 1.0;
    if (isEmpty && pass == 0) return; // attendre le 2ème pass pour les widgets async
    _checked = true;
    if (isEmpty && mounted) setState(() => _useAd = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_useAd) return FeedUnifiedAdSlot(adKey: widget.adKey);
    return KeyedSubtree(key: _key, child: widget.poolChild);
  }
}
