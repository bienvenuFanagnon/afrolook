import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/userPosts/postWidgets/postHomeWidget.dart';
import 'package:afrotok/pages/challenge/postChallengeWidget.dart';

import '../../../userPosts/postWidgets/postWidgetPage.dart';

class PostVisibilityComponent extends StatefulWidget {
  final Post post;
  final double width;
  final Color color;
  final Function(Post, VisibilityInfo) onVisibilityChanged;
  final Function(Post) onPostViewed;

  const PostVisibilityComponent({
    Key? key,
    required this.post,
    required this.width,
    required this.color,
    required this.onVisibilityChanged,
    required this.onPostViewed,
  }) : super(key: key);

  @override
  State<PostVisibilityComponent> createState() => _PostVisibilityComponentState();
}

class _PostVisibilityComponentState extends State<PostVisibilityComponent> {
  @override
  Widget build(BuildContext context) {
    final hasUserSeenPost = widget.post.hasBeenSeenByCurrentUser;

    return VisibilityDetector(
      key: Key('post-${widget.post.id}'),
      onVisibilityChanged: (VisibilityInfo info) {
        widget.onVisibilityChanged(widget.post, info);
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
          border: !hasUserSeenPost!
              ? Border.all(color: Colors.green, width: 2)
              : null,
        ),
        child: Stack(
          children: [
            // Contenu du post
            widget.post.type == PostType.CHALLENGEPARTICIPATION.name
                ? LookChallengePostWidget(
              post: widget.post,
              height: MediaQuery.of(context).size.height,
              width: widget.width,
            )
                : HomePostUsersWidget(
              post: widget.post,
              color: widget.color,
              height: MediaQuery.of(context).size.height * 0.6,
              width: widget.width,
              isDegrade: true,
            ),

            // Badge "Nouveau"
            if (!hasUserSeenPost)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fiber_new, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Nouveau',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}