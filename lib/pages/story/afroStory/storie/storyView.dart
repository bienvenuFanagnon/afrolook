import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../models/model_data.dart';
import '../../../../providers/authProvider.dart';
import '../../../../providers/postProvider.dart';
import '../util.dart';
import '../whatsapp.dart';


class StoryPreview extends StatefulWidget {
  final UserData user;
  final double h;
  final double w;
  StoryPreview({required this.user, required this.h, required this.w});

  @override
  State<StoryPreview> createState() => _StoryPreviewState();
}

class _StoryPreviewState extends State<StoryPreview> {
  @override
  Widget build(BuildContext context) {
    // double h = MediaQuery.of(context).size.height;
    // double w = MediaQuery.of(context).size.width;
    if (widget.user.stories == null || widget.user.stories!.isEmpty) {
      return Container();
    }

    final story = widget.user.stories!.last;
    Widget mediaWidget;

    if (story['mediaType'] == 'image') {
      mediaWidget = GestureDetector(
        onTap: () {
          Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => Whatsapp(userData: widget.user,)));
        },
        child: Container(
          width: widget.w,
          height: widget.h,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: NetworkImage(story['media']),
              fit: BoxFit.cover,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } else if (story['mediaType'] == 'text') {
      mediaWidget = GestureDetector(
        onTap: () {
          Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => Whatsapp(userData: widget.user,)));
        },
        child: Container(
          width: widget.w,
          height: widget.h,
          decoration: BoxDecoration(
            color:HexColor(story['color']),
            // color: Colors.brown,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              story['caption'],
              style: TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    } else {
      mediaWidget = Container();
    }

    return Stack(
      children: [
        mediaWidget,
        Positioned(
          top: 8,
          left: 8,
          child: Container(
            width: 44, // Ajustez la taille selon vos besoins
            height: 44, // Ajustez la taille selon vos besoins
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.green, // Couleur du contour
                width: 4.0, // Épaisseur du contour
              ),
            ),
            child: CircleAvatar(
              backgroundImage: NetworkImage(widget.user.imageUrl ?? ''),
              radius: 20,
            ),
          )
        ),
      ],
    );
  }
}
