// widgets/advertisement_carousel_widget.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/providers/authProvider.dart';
import '../../../services/ad_carousel_service.dart';
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
  final AdCarouselService _carouselService = AdCarouselService.instance;
  int _currentIndex = 0;
  bool _isInitializing = true;

  // Couleurs
  final Color _secondaryColor = const Color(0xFFFFD600);
  final Color _hintColor = Colors.grey[400]!;

  @override
  void initState() {
    super.initState();
    _restoreIndex();
  }

  Future<void> _restoreIndex() async {
    final savedIndex = await _carouselService.getCurrentIndex();
    if (mounted) {
      setState(() {
        _currentIndex = savedIndex;
        _isInitializing = false;
      });
    }
  }

  Future<void> _goToPrevious(List<Map<String, dynamic>> ads) async {
    if (ads.isEmpty) return;
    int newIndex = (_currentIndex - 1) % ads.length;
    if (newIndex < 0) newIndex = ads.length - 1;
    setState(() => _currentIndex = newIndex);
    await _carouselService.setCurrentIndex(newIndex);
  }

  Future<void> _goToNext(List<Map<String, dynamic>> ads) async {
    if (ads.isEmpty) return;
    int newIndex = (_currentIndex + 1) % ads.length;
    setState(() => _currentIndex = newIndex);
    await _carouselService.setCurrentIndex(newIndex);
  }

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserAuthProvider>(
      builder: (context, authProvider, child) {
        final List<Map<String, dynamic>> ads = authProvider.advertisements;

        // État de chargement : si les pubs ne sont pas encore chargées
        if (ads.isEmpty) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            height: widget.height * 0.5,
            decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(16)),
            child: const Center(child: CircularProgressIndicator(color: Color(0xFFFFD600))),
          );
        }

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
                        icon: Icon(Icons.chevron_left, color: _secondaryColor, size: 28),
                        onPressed: () => _goToPrevious(ads),
                      ),
                      ...List.generate(ads.length, (index) {
                        return GestureDetector(
                          onTap: () async {
                            setState(() => _currentIndex = index);
                            await _carouselService.setCurrentIndex(index);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: _currentIndex == index ? 20 : 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: _currentIndex == index ? _secondaryColor : _secondaryColor.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        );
                      }),
                      IconButton(
                        icon: Icon(Icons.chevron_right, color: _secondaryColor, size: 28),
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