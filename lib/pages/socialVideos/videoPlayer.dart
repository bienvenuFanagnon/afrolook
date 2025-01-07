import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/material.dart';
import 'package:flick_video_player/flick_video_player.dart';
import 'package:video_player/video_player.dart';
class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;

  VideoPlayerWidget({Key? key, required this.videoUrl}) : super(key: key);

  @override
  _VideoPlayerWidgetState createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _videoPlayerController;
  late ChewieController _chewieController;

  @override
  void initState() {
    super.initState();
    _videoPlayerController = VideoPlayerController.network(widget.videoUrl);
    _chewieController = ChewieController(
      videoPlayerController: _videoPlayerController,
      materialProgressColors: ChewieProgressColors(backgroundColor: Colors.green,playedColor: Colors.green,handleColor: Colors.green),
      cupertinoProgressColors: ChewieProgressColors(backgroundColor: Colors.green,playedColor: Colors.green,handleColor: Colors.green),
      aspectRatio: 16 / 12, // Réglage de l'aspect ratio de la vidéo
      autoPlay: false, // Définir si la vidéo doit démarrer automatiquement
      looping: false, // Définir si la vidéo doit être en mode boucle
     allowFullScreen: false,
      autoInitialize: true,
      //startAt: Duration(seconds: 1),
      fullScreenByDefault: false,
        errorBuilder: (context, errorMessage) => Container(width: 50,height: 50, child: CircularProgressIndicator(color: Colors.green,)),
    );
  }



  @override
  void dispose() {
    super.dispose();
    _videoPlayerController.dispose();
    _chewieController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Chewie(

      controller: _chewieController,

    );
  }
}

