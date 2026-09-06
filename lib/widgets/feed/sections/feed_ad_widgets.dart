import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../pages/admin/AfrolookPub/advertisementCarouselWidget.dart';
import '../../../pages/pub/afrolook_inline_ad.dart';
import '../../../providers/authProvider.dart';

/// Bannière désactivée — Appodeal n'est plus utilisé.
class FeedAdBanner extends StatelessWidget {
  final String adKey;
  const FeedAdBanner({Key? key, required this.adKey}) : super(key: key);

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Slot MREC désactivé — Appodeal n'est plus utilisé, pas d'espace blanc.
class FeedAdMrec extends StatelessWidget {
  final String adKey;
  const FeedAdMrec({Key? key, required this.adKey}) : super(key: key);

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
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
    // Hauteur image : ratio 4:3 pour s'aligner avec les posts normaux du feed
    final imageHeight = cardWidth * 0.65;

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

/// Slot pub unifié : alterne entre carousel et bannière.
///
/// - Si des post-ads existent : alterne carousel / bannière (1 sur 2)
/// - Si seulement entity boosts : toujours bannière
/// - Vide → rien (invisible, pas de saut de layout)
///
/// Le format est verrouillé au premier chargement des pubs pour éviter
/// le passage bannière → carousel lors du chargement asynchrone.
class FeedUnifiedAdSlot extends StatefulWidget {
  final String adKey;
  const FeedUnifiedAdSlot({Key? key, required this.adKey}) : super(key: key);

  static int _slotCounter = 0;

  @override
  State<FeedUnifiedAdSlot> createState() => _FeedUnifiedAdSlotState();
}

class _FeedUnifiedAdSlotState extends State<FeedUnifiedAdSlot> {
  /// null = pas encore décidé ; true = carousel ; false = bannière
  bool? _showCarousel;

  @override
  Widget build(BuildContext context) {
    return Consumer<UserAuthProvider>(
      builder: (context, auth, _) {
        if (auth.advertisements.isEmpty) return const SizedBox.shrink();

        // Verrouiller le format une seule fois, au premier chargement non vide.
        if (_showCarousel == null) {
          final hasPostAds = auth.advertisements
              .any((a) => a['isEntityBoost'] != true && a['post'] != null);
          if (hasPostAds) {
            _showCarousel = (FeedUnifiedAdSlot._slotCounter % 2 == 0);
            FeedUnifiedAdSlot._slotCounter++;
          } else {
            _showCarousel = false;
          }
        }

        return _showCarousel == true
            ? FeedAdCarousel(adKey: widget.adKey)
            : const AfrolookInlineAd();
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
