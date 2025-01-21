import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../models/model_data.dart';
import '../../../../providers/authProvider.dart';
import '../../../../providers/postProvider.dart';
import '../../../component/showUserDetails.dart';
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
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  @override
  Widget build(BuildContext context) {
    double h = MediaQuery.of(context).size.height;
    double w = MediaQuery.of(context).size.width;
    if (widget.user.stories == null || widget.user.stories!.isEmpty) {
      return Container();
    }

    final story = widget.user.stories!.last;
    Widget mediaWidget;
    printVm("story data last : ${widget.user.stories!.first.toJson()}");
    printVm("story data : ${story.toJson()}");

    if (story.mediaType!.name == 'image') {
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
              image: NetworkImage(story.media!),
              fit: BoxFit.cover,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } else if (story.mediaType!.name! == 'text') {
      mediaWidget = GestureDetector(
        onTap: () {
          Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => Whatsapp(userData: widget.user,)));
        },
        child: Container(
          width: widget.w,
          height: widget.h,
          decoration: BoxDecoration(
            color:HexColor(story.color!),
            // color: Colors.brown,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              story.caption!,
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
          child: GestureDetector(
            onTap: () async {
              await  authProvider.getUserById(widget.user.id!).then((users) async {
                if(users.isNotEmpty){
                  showUserDetailsModalDialog(users.first, w, h,context);

                }
              },);

            },
            child: Container(
              width: 44, // Ajustez la taille selon vos besoins
              height: 44, // Ajustez la taille selon vos besoins
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white, // Couleur du contour
                  width: 4.0, // Épaisseur du contour
                ),
              ),
              child: CircleAvatar(
                backgroundImage: NetworkImage(widget.user.imageUrl ?? ''),
                radius: 20,
              ),
            ),
          )
        ),
        // Positioned(
        //   bottom: 0,
        //   left: 0,
        //   right: 0,
        //   child: Stack(
        //     children: [
        //       Container(
        //         height: 50,
        //         // width: w,
        //         decoration: BoxDecoration(
        //           gradient: LinearGradient(
        //             colors: [
        //               // ConstColors.buttonColors,
        //               Colors.green.shade300,
        //
        //               // ConstColors.secondaryColor,
        //
        //               Color.fromARGB(0, 0, 0, 0)
        //             ],
        //             begin: Alignment.bottomCenter,
        //             end: Alignment.topCenter,
        //           ),
        //         ),
        //         padding: EdgeInsets.symmetric(
        //             vertical: 10.0, horizontal: 20.0),
        //       ),
        //
        //       Positioned(
        //         bottom: 1,
        //         left: 3,
        //         right: 3,
        //         child: Row(
        //           mainAxisAlignment: MainAxisAlignment.spaceBetween,
        //           children: [
        //             Row(
        //               children: [
        //                 Icon(Icons.remove_red_eye, color: Colors.white, size: 10),
        //                 SizedBox(width: 2),
        //                 Text(
        //                   '${story.nbrVues}',
        //                   style: TextStyle(color: Colors.white, fontSize: 10),
        //                 ),
        //               ],
        //             ),
        //             Row(
        //               children: [
        //                 Icon(
        //                   story.jaimes.contains('currentUserId')
        //                       ? Icons.favorite
        //                       : Icons.favorite_border,
        //                   color: Colors.red,
        //                   size: 10,
        //                 ),
        //                 SizedBox(width: 2),
        //                 Text(
        //                   '${story.nbrJaimes}',
        //                   style: TextStyle(color: Colors.white, fontSize: 10),
        //                 ),
        //               ],
        //             ),
        //           ],
        //         ),
        //       ),
        //     ],
        //   ),
        // ),
      ],
    );
  }
}
