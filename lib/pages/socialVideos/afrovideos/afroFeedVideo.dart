import 'dart:async';
import 'package:afrotok/pages/socialVideos/afrovideos/videoWidget.dart';
import 'package:flutter/material.dart';
import 'package:like_button/like_button.dart';
import 'package:provider/provider.dart';

import '../../../models/model_data.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/postProvider.dart';
import '../../../providers/userProvider.dart';

class VideoFeedPage extends StatefulWidget {
  @override
  _VideoFeedPageState createState() => _VideoFeedPageState();
}

class _VideoFeedPageState extends State<VideoFeedPage> {
  final PageController _pageController = PageController();

  StreamController<List<Post>> _streamController = StreamController<List<Post>>();
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  late PostProvider postProvider =
  Provider.of<PostProvider>(context, listen: false);
  late UserProvider userProvider =
  Provider.of<UserProvider>(context, listen: false);
  bool _showHeart = false;
  bool _showGift = false;
  void _triggerAnimation(String type) {
    setState(() {
      if (type == 'like') _showHeart = true;
      if (type == 'gift') _showGift = true;
    });

    Timer(Duration(milliseconds: 1000), () {
      setState(() {
        if (type == 'like') _showHeart = false;
        if (type == 'gift') _showGift = false;
      });
    });
  }

  Widget _buildAnimationOverlay() {
    return Stack(
      children: [
        AnimatedOpacity(
          opacity: _showHeart ? 1.0 : 0.0,
          duration: Duration(seconds: 2),
          child: Center(
            child: Icon(
              Icons.favorite,
              color: Colors.red,
              size: 100,
            ),
          ),
        ),
        AnimatedOpacity(
          opacity: _showGift ? 1.0 : 0.0,
          duration: Duration(seconds: 2),
          child: Center(
            child: Icon(
              Icons.card_giftcard,
              color: Colors.amber,
              size: 100,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSideToolbar(Post post) {
    return Positioned(
      right: 10,
      bottom: 100,
      child: Column(
        children: [
          LikeButton(
            onTap: (isLiked) async {
              _triggerAnimation('like');
              // Ajouter ici la logique de like
              return !isLiked;
            },
            size: 40,
            likeBuilder: (isLiked) => Icon(
              Icons.favorite,
              color: isLiked ? Colors.red : Colors.white,
            ),
            likeCount: post.likes,
          ),
          SizedBox(height: 20),
          IconButton(
            icon: Icon(Icons.comment, size: 40, color: Colors.white),
            onPressed: () {
              // Navigator.push(context,
              //     MaterialPageRoute(builder: (_) => CommentsPage(post: post)));
            },
          ),
          SizedBox(height: 20),
          IconButton(
            icon: Icon(Icons.card_giftcard, size: 40, color: Colors.white),
            onPressed: () => _triggerAnimation('gift'),
          ),
          SizedBox(height: 20),
          Icon(Icons.visibility,
              size: 30,
              color: Colors.white),
          Text('${post.vues}',
              style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildVideoItem(Post post) {
    return Stack(
      children: [
        // VideoPlayer(url: post.url_media),
        SamplePlayer(post: post),
        _buildAnimationOverlay(),
        _buildSideToolbar(post),
        Positioned(
          bottom: 20,
          left: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('@${post.user!.pseudo}',
                  style: TextStyle(color: Colors.white, fontSize: 16)),
              SizedBox(height: 8),
              Text(post.description!,
                  style: TextStyle(color: Colors.white)),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.music_note, color: Colors.white, size: 15),
                  Text('Son original',
                      style: TextStyle(color: Colors.white)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    postProvider.getPostsVideos(10).listen((data) {
      _streamController.add(data);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: StreamBuilder<List<Post>>(
        stream: _streamController.stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Icon(Icons.error));
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

          return PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              return _buildVideoItem(snapshot.data![index]);
            },
          );
        },
      ),
    );
  }
}