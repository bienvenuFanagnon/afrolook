import 'package:flutter/material.dart';
import 'dart:async';

class LiveStreamPage extends StatefulWidget {
  @override
  _LiveStreamPageState createState() => _LiveStreamPageState();
}

class _LiveStreamPageState extends State<LiveStreamPage> with WidgetsBindingObserver, TickerProviderStateMixin {
  final TextEditingController _commentController = TextEditingController();
  final List<Comment> _comments = [];
  final List<AnimationController> _heartAnimations = [];
  final List<AnimationController> _giftAnimations = [];

  void _addComment(String text) {
    setState(() {
      _comments.insert(0, Comment(user: "User${_comments.length}", text: text));
    });
  }

  void _sendLike() {
    final controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    );
    setState(() {
      _heartAnimations.add(controller);
    });
    controller.forward().then((_) {
      setState(() {
        _heartAnimations.remove(controller);
      });
    });
  }

  void _sendGift(String gift) {
    final controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    );
    setState(() {
      _giftAnimations.add(controller);
    });
    controller.forward().then((_) {
      setState(() {
        _giftAnimations.remove(controller);
      });
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Zone de la vidéo en direct
          Container(
            color: Colors.black,
            child: Center(
              child: Text(
                'LIVE VIDEO',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),

          // Commentaires
          Positioned(
            bottom: 100,
            left: 10,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.7,
              height: 200,
              child: ListView.builder(
                reverse: true,
                itemCount: _comments.length,
                itemBuilder: (context, index) {
                  final comment = _comments[index];
                  return CommentBubble(comment: comment);
                },
              ),
            ),
          ),

          // Champ de commentaire
          Positioned(
            bottom: 20,
            left: 10,
            right: 10,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Commentaire...',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    onSubmitted: (text) {
                      _addComment(text);
                      _commentController.clear();
                    },
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.favorite, color: Colors.red),
                  onPressed: _sendLike,
                ),
                IconButton(
                  icon: Icon(Icons.card_giftcard, color: Colors.amber),
                  onPressed: () => _sendGift('🎁'),
                ),
              ],
            ),
          ),

          // Animations des likes
          ..._heartAnimations.map((controller) => HeartAnimation(controller: controller)),

          // Animations des cadeaux
          ..._giftAnimations.map((controller) => GiftAnimation(controller: controller)),
        ],
      ),
    );
  }
}

class Comment {
  final String user;
  final String text;

  Comment({required this.user, required this.text});
}

class CommentBubble extends StatelessWidget {
  final Comment comment;

  const CommentBubble({required this.comment});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 2),
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(15),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '${comment.user}: ',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextSpan(
              text: comment.text,
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class HeartAnimation extends StatelessWidget {
  final AnimationController controller;

  const HeartAnimation({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Center(
          child: Opacity(
            opacity: 1 - controller.value,
            child: Transform.scale(
              scale: 1 + controller.value * 2,
              child: Icon(
                Icons.favorite,
                color: Colors.red,
                size: 100,
              ),
            ),
          ),
        );
      },
    );
  }
}

class GiftAnimation extends StatelessWidget {
  final AnimationController controller;

  const GiftAnimation({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Center(
          child: Opacity(
            opacity: 1 - controller.value,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.scale(
                  scale: 1 + controller.value,
                  child: Text(
                    '🎁',
                    style: TextStyle(fontSize: 80),
                  ),
                ),
                Text(
                  'User a envoyé un cadeau!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    shadows: [
                      Shadow(
                        color: Colors.black,
                        blurRadius: 10,
                        offset: Offset(2, 2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}