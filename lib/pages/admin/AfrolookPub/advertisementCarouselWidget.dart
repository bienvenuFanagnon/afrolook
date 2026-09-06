// widgets/advertisement_carousel_widget.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/providers/authProvider.dart';
import '../../../pages/pub/afrolook_inline_ad.dart';
import '../../../services/ad_rotation_service.dart';
import '../../../theme/app_colors.dart';
import 'advertisementPostImageWidget.dart';
import 'advertisement_video_widget.dart';

class AdvertisementCarouselWidget extends StatefulWidget {
  final double height;
  final double width;
  final bool showIndicators;
  final Function(Post, Advertisement)? onAdClicked;
  final Function(Post, Advertisement)? onAdViewed;

  const AdvertisementCarouselWidget({
    Key? key,
    required this.height,
    required this.width,
    this.showIndicators = true,
    this.onAdClicked,
    this.onAdViewed,
  }) : super(key: key);

  @override
  State<AdvertisementCarouselWidget> createState() => _AdvertisementCarouselWidgetState();
}

class _AdvertisementCarouselWidgetState extends State<AdvertisementCarouselWidget> {
  int _currentIndex = 0;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initIndex();
  }

  void _initIndex() {
    // Le carousel démarre à la position courante du service de rotation,
    // puis réclame un slot (avance le compteur global).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<UserAuthProvider>();
      final ads = auth.advertisements
          .where((a) => a['isEntityBoost'] != true && a['post'] != null)
          .toList();
      if (ads.isNotEmpty) {
        final idx = AdRotationService.instance.claimNext(ads.length);
        setState(() {
          _currentIndex = idx;
          _isInitializing = false;
        });
      } else {
        setState(() => _isInitializing = false);
      }
    });
  }

  void _goToPrevious(List<Map<String, dynamic>> ads) {
    if (ads.isEmpty) return;
    final newIndex = AdRotationService.instance.carouselPrev(ads.length);
    setState(() => _currentIndex = newIndex);
  }

  void _goToNext(List<Map<String, dynamic>> ads) {
    if (ads.isEmpty) return;
    final newIndex = AdRotationService.instance.carouselNext(ads.length);
    setState(() => _currentIndex = newIndex);
  }

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Consumer<UserAuthProvider>(
      builder: (context, authProvider, child) {
        // Filtrer les boosts entité (pas de post) — ce carousel ne gère que les pubs post
        final List<Map<String, dynamic>> ads = authProvider.advertisements
            .where((a) => a['isEntityBoost'] != true && a['post'] != null)
            .toList();

        // Aucune post-ad disponible → fallback bannière (évite le spinner infini)
        if (ads.isEmpty) return const AfrolookInlineAd();

        // Ajuster l'index si la liste a changé (par ex. après un refresh)
        if (_currentIndex >= ads.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _currentIndex = 0);
          });
        }

        final currentAdData = ads[_currentIndex % ads.length];
        final post = Post.fromJson(currentAdData['post']);
        final ad = Advertisement.fromJson(currentAdData['ad']);
        final bool isVideo = post.dataType == PostDataType.VIDEO.name ||
            (post.url_media?.contains('.mp4') ?? false) ||
            (post.url_media?.contains('.mov') ?? false);

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              isVideo
                  ? AdvertisementVideoWidget(
                post: post,
                ad: ad,
                width: widget.width,
                height: widget.height,
                onAdClicked: widget.onAdClicked,
                onAdViewed: widget.onAdViewed,
              )
                  : AdvertisementPostImageWidget(
                post: post,
                ad: ad,
                width: widget.width,
                height: widget.height,
                onAdClicked: widget.onAdClicked,
                onAdViewed: widget.onAdViewed,
              ),
              if (widget.showIndicators && ads.length > 1)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(Icons.chevron_left, color: colors.accent, size: 28),
                        onPressed: () => _goToPrevious(ads),
                      ),
                      ...List.generate(ads.length, (index) {
                        return GestureDetector(
                          onTap: () {
                            setState(() => _currentIndex = index);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: _currentIndex == index ? 20 : 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: _currentIndex == index ? colors.accent : colors.accent.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        );
                      }),
                      IconButton(
                        icon: Icon(Icons.chevron_right, color: colors.accent, size: 28),
                        onPressed: () => _goToNext(ads),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}