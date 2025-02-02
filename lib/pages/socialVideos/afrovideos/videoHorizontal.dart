import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:video_player/video_player.dart';

class VideoCarousel extends StatefulWidget {
  @override
  _VideoCarouselState createState() => _VideoCarouselState();
}

class _VideoCarouselState extends State<VideoCarousel> {
  final PageController _pageController = PageController(viewportFraction: 0.85);
  late List<VideoPlayerController> _videoControllers;
  int _currentIndex = 0;

  final List<String> videoUrls = [
    'https://firebasestorage.googleapis.com/v0/b/afrolooki.appspot.com/o/post_media%2F1000017824.mp4?alt=media&token=8365ac4a-9986-44a2-aa9d-bcb06ea68198',
    'https://firebasestorage.googleapis.com/v0/b/afrolooki.appspot.com/o/post_media%2F1000017824.mp4?alt=media&token=8365ac4a-9986-44a2-aa9d-bcb06ea68198',
    'https://firebasestorage.googleapis.com/v0/b/afrolooki.appspot.com/o/post_media%2F1000017824.mp4?alt=media&token=8365ac4a-9986-44a2-aa9d-bcb06ea68198',
    'https://firebasestorage.googleapis.com/v0/b/afrolooki.appspot.com/o/post_media%2F1000017824.mp4?alt=media&token=8365ac4a-9986-44a2-aa9d-bcb06ea68198',
  ];

  @override
  void initState() {
    super.initState();
    _initializeVideoControllers();
    _pageController.addListener(_onPageScroll);
  }

  void _initializeVideoControllers() {
    _videoControllers = videoUrls
        .map((url) => VideoPlayerController.network(url)
      ..setLooping(true)
      ..initialize().then((_) {
        if (mounted) setState(() {});
      }))
        .toList();
  }

  void _onPageScroll() {
    final newIndex = (_pageController.page ?? 0).round();
    if (newIndex != _currentIndex) {
      setState(() {
        _videoControllers[_currentIndex].pause();
        _currentIndex = newIndex;
        _videoControllers[_currentIndex].play();
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (var controller in _videoControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        itemCount: videoUrls.length,
        itemBuilder: (context, index) {
          final controller = _videoControllers[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: controller.value.isInitialized
                  ? HtmlWidget(
                 """
                      <video width="100%" height="auto" controls>
                        <source src="${videoUrls[index]}" type="video/mp4">
                        Your browser does not support the video tag.
                      </video>
                      """,
              )
                  : Center(child: CircularProgressIndicator()),
            ),
          );
        },
      ),
    );
  }
}