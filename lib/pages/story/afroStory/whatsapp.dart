import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/story/afroStory/repository.dart';
import 'package:afrotok/pages/story/afroStory/util.dart';
import 'package:afrotok/pages/story/afroStory/widgets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:story_view/story_view.dart';

import '../../../providers/authProvider.dart';


class Whatsapp extends StatefulWidget {
  UserData userData;
  Whatsapp({required this.userData});
  @override
  State<Whatsapp> createState() => _WhatsappState();
}

class _WhatsappState extends State<Whatsapp> {

  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<WhatsappStory>>(
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return StoryViewDelegate(
              stories: snapshot.data, userData: widget.userData,
            );
          }

          if (snapshot.hasError) {
            return ErrorView();
          }

          return Center(
            child: SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(),
            ),
          );
        },
        future: Repository.getWhatsappStories(widget.userData.stories),
      ),
    );
  }
}

class StoryViewDelegate extends StatefulWidget {
  final List<WhatsappStory>? stories;
  final UserData userData;

  StoryViewDelegate({this.stories, required this.userData});

  @override
  _StoryViewDelegateState createState() => _StoryViewDelegateState();
}

class _StoryViewDelegateState extends State<StoryViewDelegate> {
  final StoryController controller = StoryController();
  List<StoryItem> storyItems = [];
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  String? when = "";

  @override
  void initState() {
    super.initState();
    widget.stories!.forEach((story) {
      if (story.mediaType == MediaType.text) {
        // story.incrementViews(widget.userData.id!)
        // _incrementViews(story, widget.userData);
        storyItems.add(
          StoryItem.text(
            title: story.caption!,
            backgroundColor: HexColor(story.color!),
            duration: Duration(
              milliseconds: (story.duration! * 1000).toInt(),
            ),
          ),
        );
      }

      if (story.mediaType == MediaType.image) {
        storyItems.add(StoryItem.pageImage(
          url: story.media!,
          controller: controller,
          caption: Text(story.caption!),
          duration: Duration(
            milliseconds: (story.duration! * 1000).toInt(),
          ),
        ));
      }

      if (story.mediaType == MediaType.video) {
        storyItems.add(
          StoryItem.pageVideo(
            story.media!,
            controller: controller,
            duration: Duration(milliseconds: (story.duration! * 1000).toInt()),
            caption: Text(story.caption!),
          ),
        );
      }
    });

    when = widget.stories![0].when;
  }

  Widget _buildProfileView(UserData userData) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        CircleAvatar(
          radius: 20,
          backgroundImage: NetworkImage(
              "${userData.imageUrl}"),
        ),
        SizedBox(
          width: 16,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                "@${userData.pseudo}",
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              Text(
                when!,
                style: TextStyle(
                  color: Colors.white60,
                ),
              )
            ],
          ),
        )
      ],
    );
  }

  void _incrementViews(WhatsappStory story,UserData user) {
    setState(() {
     // var indexOf= user.stories!.indexOf(story);
      story.nbrVues += 1;
     //  var userData=user;
     // userData.stories![indexOf]=story;
     // authProvider.updateUser(userData);

    });
  }

  void _toggleLike(UserData user,UserData userLike,int index) {
    var story= user.stories!.elementAt(index);
    setState(() {
      if (story.jaimes.contains(userLike.id)) {
        story.jaimes.remove(userLike.id);
      } else {
        story.jaimes.add(userLike.id!);
      }
      story.nbrJaimes = story.jaimes.length;
      user.stories![index]=story;

    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        StoryView(
          indicatorColor: Colors.green,
          storyItems: storyItems,
          controller: controller,
          
          onComplete: () {
            Navigator.of(context).pop();
          },
          onVerticalSwipeComplete: (v) {
            if (v == Direction.down) {
              Navigator.pop(context);
            }
          },
          onStoryShow: (storyItem, index) {
           // var storieMap= widget.userData.stories!.elementAt(index);
           //  _incrementViews(widget.userData,index);
          },
        ),
        Container(
          padding: EdgeInsets.only(
            top: 80,
            left: 16,
            right: 16,
          ),
          child: _buildProfileView(widget.userData),
        ),
        Positioned(
          top: 80,
          right: 16,
          child: Text(
            '@afrolook',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.lightGreenAccent,
            ),
          ),
        ),
        // Positioned(
        //   bottom: 16,
        //   left: 16,
        //   child: Row(
        //     children: [
        //       Icon(Icons.remove_red_eye, color: Colors.white),
        //       SizedBox(width: 4),
        //       Text(
        //         '${widget.story['nbrVues']} vues',
        //         style: TextStyle(color: Colors.white),
        //       ),
        //     ],
        //   ),
        // ),
        // Positioned(
        //   bottom: 16,
        //   right: 16,
        //   child: Row(
        //     children: [
        //       IconButton(
        //         icon: Icon(
        //           widget.story['jaimes'].contains('currentUserId')
        //               ? Icons.favorite
        //               : Icons.favorite_border,
        //           color: Colors.red,
        //         ),
        //         onPressed: _toggleLike,
        //       ),
        //       SizedBox(width: 4),
        //       Text(
        //         '${widget.story['nbrJaimes']} j\'aime',
        //         style: TextStyle(color: Colors.white),
        //       ),
        //     ],
        //   ),
        // ),
      ],
    );
  }
}