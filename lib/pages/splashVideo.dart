import 'package:afrotok/pages/splashChargement.dart';
import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';
import 'package:video_player/video_player.dart';

class SplashVideo extends StatefulWidget {
  @override
  _SplashVideoState createState() => _SplashVideoState();
}

class _SplashVideoState extends State<SplashVideo> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('assets/videos/intro_video.mp4')
      ..initialize().then((_) {
        setState(() {});
        _controller.setVolume(0.0); // Couper le son
        _controller.play();
      });

    _controller.addListener(() {
      if (_controller.value.position == _controller.value.duration) {
        // Navigator.of(context).pushReplacement(
        Navigator.of(context).pushReplacement(
          PageTransition(
            type: PageTransitionType.fade,
            duration: Duration(milliseconds: 2000), // Ajuste la durée selon tes besoins
            child: SplahsChargement(postId: "", postType: '',),
          ),
        );
        // Navigator.of(context).pushReplacement(
        //   MaterialPageRoute(builder: (context) => SplahsChargement(postId: "")),
        // );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _controller.value.isInitialized
          ? SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _controller.value.size.width,
            height: _controller.value.size.height,
            child: VideoPlayer(_controller),
          ),
        ),
      )
          : Center(child: CircularProgressIndicator()),
    );
  }
}