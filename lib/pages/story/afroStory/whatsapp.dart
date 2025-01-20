import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/story/afroStory/repository.dart';
import 'package:afrotok/pages/story/afroStory/util.dart';
import 'package:afrotok/pages/story/afroStory/widgets.dart';
import 'package:flutter/material.dart';
import 'package:story_view/story_view.dart';


class Whatsapp extends StatefulWidget {
  UserData userData;
  Whatsapp({required this.userData});
  @override
  State<Whatsapp> createState() => _WhatsappState();
}

class _WhatsappState extends State<Whatsapp> {
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

  String? when = "";

  @override
  void initState() {
    super.initState();
    widget.stories!.forEach((story) {
      if (story.mediaType == MediaType.text) {
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

    int pos = storyItems.indexOf(storyItem);

    // the reason for doing setState only after the first
    // position is becuase by the first iteration, the layout
    // hasn't been laid yet, thus raising some exception
    // (each child need to be laid exactly once)
    if (pos > 0) {
      setState(() {
        // when = widget.stories![pos].when;
        when = widget.stories![index].when;
      });
    }

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
      ],
    );
  }
}
