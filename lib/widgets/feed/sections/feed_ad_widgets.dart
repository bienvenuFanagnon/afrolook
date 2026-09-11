import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/model_data.dart';
import '../../../pages/admin/AfrolookPub/advertisementPostImageWidget.dart';
import '../../../pages/admin/AfrolookPub/advertisement_video_widget.dart';
import '../../../pages/pub/afrolook_inline_ad.dart';
import '../../../providers/authProvider.dart';
import '../../../services/ad_rotation_service.dart';
import 'feed_creator_posts_card.dart';

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

/// Grand format pub Afrolook — affiche UNE seule pub sélectionnée par rotation.
/// Pas de boutons de navigation, pas d'indicateurs.
class FeedAdCarousel extends StatefulWidget {
  final String adKey;
  const FeedAdCarousel({Key? key, required this.adKey}) : super(key: key);

  @override
  State<FeedAdCarousel> createState() => _FeedAdCarouselState();
}

class _FeedAdCarouselState extends State<FeedAdCarousel> {
  int? _adIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<UserAuthProvider>();
      final ads = auth.advertisements
          .where((a) => a['isEntityBoost'] != true && a['post'] != null)
          .toList();
      if (ads.isNotEmpty) {
        setState(() => _adIndex = AdRotationService.instance.claimNext(ads.length));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserAuthProvider>(
      builder: (context, auth, _) {
        final ads = auth.advertisements
            .where((a) => a['isEntityBoost'] != true && a['post'] != null)
            .toList();
        if (ads.isEmpty) return const AfrolookInlineAd();

        final idx = (_adIndex ?? 0) % ads.length;
        final currentAdData = ads[idx];
        final post = Post.fromJson(currentAdData['post']);
        final ad = Advertisement.fromJson(currentAdData['ad']);

        final screenWidth = MediaQuery.of(context).size.width;
        const hMargin = 12.0;
        final cardWidth = screenWidth - hMargin * 2;
        final imageHeight = cardWidth * 1.06;

        final bool isVideo = post.dataType == PostDataType.VIDEO.name ||
            (post.url_media?.contains('.mp4') ?? false) ||
            (post.url_media?.contains('.mov') ?? false);

        return KeyedSubtree(
          key: ValueKey(widget.adKey),
          child: isVideo
              ? AdvertisementVideoWidget(
                  post: post,
                  ad: ad,
                  width: cardWidth,
                  height: imageHeight,
                )
              : AdvertisementPostImageWidget(
                  post: post,
                  ad: ad,
                  width: cardWidth,
                  height: imageHeight,
                ),
        );
      },
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

/// Slot boost entité (profil / canal) — affiche UNE pub entité comme FeedCreatorPostsCard.
/// Si aucun boost entité disponible, affiche [fallback] (ou rien si null).
class FeedEntityBoostSlot extends StatefulWidget {
  final String adKey;
  final Widget? fallback;
  const FeedEntityBoostSlot({Key? key, required this.adKey, this.fallback})
      : super(key: key);

  @override
  State<FeedEntityBoostSlot> createState() => _FeedEntityBoostSlotState();
}

class _FeedEntityBoostSlotState extends State<FeedEntityBoostSlot> {
  int? _adIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<UserAuthProvider>();
      final boosts = auth.advertisements
          .where((a) => a['isEntityBoost'] == true)
          .toList();
      if (boosts.isNotEmpty) {
        setState(() =>
            _adIndex = AdRotationService.instance.claimNext(boosts.length));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserAuthProvider>(
      builder: (context, auth, _) {
        final boosts = auth.advertisements
            .where((a) => a['isEntityBoost'] == true)
            .toList();
        if (boosts.isEmpty) return widget.fallback ?? const SizedBox.shrink();
        final idx = (_adIndex ?? 0) % boosts.length;
        try {
          final adMap = boosts[idx]['ad'] as Map<String, dynamic>?;
          if (adMap == null) return widget.fallback ?? const SizedBox.shrink();
          final ad = Advertisement.fromJson(adMap);
          return FeedCreatorPostsCard(key: ValueKey(widget.adKey), ad: ad);
        } catch (_) {
          return widget.fallback ?? const SizedBox.shrink();
        }
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
