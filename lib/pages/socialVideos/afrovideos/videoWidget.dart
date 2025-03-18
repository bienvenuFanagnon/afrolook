

import 'package:chewie/chewie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flick_video_player/flick_video_player.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../../models/chatmodels/message.dart';
import '../../../models/model_data.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/postProvider.dart';
import '../../../providers/userProvider.dart';
import '../../component/consoleWidget.dart';


class VideoWidget extends StatefulWidget {
  final Post post;

  const VideoWidget({Key? key, required this.post}) : super(key: key);

  @override
  _VideoWidgetState createState() => _VideoWidgetState();
}

class _VideoWidgetState extends State<VideoWidget> {
  late VideoPlayerController videoPlayerController;
  late Future<void> _initializeVideoPlayerFuture;
  ChewieController? _chewieController;
  late PostProvider postProvider =
  Provider.of<PostProvider>(context, listen: false);
  @override
  void initState() {
    super.initState();
    videoInit();
  }

  @override
  void dispose() {
    videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  void videoInit() {
    videoPlayerController = VideoPlayerController.network(widget.post.url_media!);
    _initializeVideoPlayerFuture = videoPlayerController.initialize().then((_) {
      setState(() {
        _chewieController = ChewieController(
          videoPlayerController: videoPlayerController,
          autoPlay: true,
          looping: true,
          aspectRatio: videoPlayerController.value.aspectRatio,
        );
      });
    }).catchError((error) {
      debugPrint('Erreur lors de l\'initialisation du lecteur vidéo : $error');
    });

    if (widget.post?.id != null) {
      postProvider.getPostsVideosById(widget.post.id!).then((value) {
        if (value.isNotEmpty) {
          final updatedPost = value.first;
          if (updatedPost.vues != null) {
            updatedPost.vues = (updatedPost.vues ?? 0) + 1;
          }

          if (updatedPost.user != null) {
            postProvider.updatePost(updatedPost, updatedPost.user!, context);
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initializeVideoPlayerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return videoPlayerController.value.isInitialized
              ? GestureDetector(
            onTap: () {
              setState(() {
                videoPlayerController.value.isPlaying
                    ? videoPlayerController.pause()
                    : videoPlayerController.play();
              });
            },
            child: AspectRatio(
              aspectRatio: videoPlayerController.value.aspectRatio,
              child: _chewieController != null
                  ? Chewie(controller: _chewieController!)
                  : Center(child: CircularProgressIndicator()),
            ),
          )
              : Center(child: CircularProgressIndicator());
        } else {
          return Center(child: CircularProgressIndicator());
        }
      },
    );
  }
}


class SamplePlayer extends StatefulWidget {
  final Post post;

  SamplePlayer({Key? key, required this.post}) : super(key: key);

  @override
  _SamplePlayerState createState() => _SamplePlayerState();
}

class _SamplePlayerState extends State<SamplePlayer> {
  late FlickManager flickManager;
  @override
  void initState() {
    super.initState();
    // flickManager = FlickManager(
    //     videoPlayerController:
    //     VideoPlayerController.networkUrl(Uri.parse(widget.post.url_media!),
    //     ) );
    if (mounted) {
      flickManager = FlickManager(
        autoPlay: true,
        autoInitialize: true,

        videoPlayerController: VideoPlayerController.networkUrl(
          Uri.parse(widget.post.url_media!),

        )..setLooping(true),
      );
  }
  }

  @override
  void dispose() {
    flickManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: FlickVideoPlayer(
          flickManager: flickManager
      ),
    );
  }
}