import 'dart:ffi';

import 'package:afrotok/models/model_data.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:like_button/like_button.dart';
import 'package:rate_in_stars/rate_in_stars.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:flutter_animated_icons/icons8.dart';
import 'package:flutter_animated_icons/lottiefiles.dart';
import 'package:flutter_animated_icons/useanimations.dart';
import 'package:lottie/lottie.dart';
import '../../constant/constColors.dart';
import '../../constant/textCustom.dart';

class DetailsOtherUser extends StatefulWidget {
  final UserData user;
  final double w;
  final double h;
  const DetailsOtherUser({super.key, required this.user, required this.w, required this.h});

  @override
  State<DetailsOtherUser> createState() => _DetailsOtherUserState();
}

class _DetailsOtherUserState extends State<DetailsOtherUser> with TickerProviderStateMixin {

  late AnimationController _starController;
  late AnimationController _unlikeController;
  late Animation<double> _offsetAnimation ;
  late Animation<double> _starAnimation ;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    _starController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _unlikeController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _offsetAnimation = Tween<double>(
      begin: 0.0,
      end: 90/360,
    ).animate(_unlikeController);

    _starAnimation = Tween<double>(
      begin: 1.0,
      end: 0.8,
    ).animate(_starController);
  }
  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    _starController.dispose();
    _unlikeController.dispose();

  }
  @override
  Widget build(BuildContext context) {
    double taux=widget.user.popularite!*100;
    return SingleChildScrollView(
      child: Column(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.only(topLeft: Radius.circular(10),topRight: Radius.circular(10)),
            child: Container(
              width: widget.w*0.8,
              height: widget.h*0.4,
              child: CachedNetworkImage(
                fit: BoxFit.cover,

                imageUrl: '${widget.user.imageUrl!}',
                progressIndicatorBuilder: (context, url, downloadProgress) =>
                //  LinearProgressIndicator(),

                Skeletonizer(
                    child: SizedBox(width: 120,height: 100, child:  ClipRRect(
                        borderRadius: BorderRadius.all(Radius.circular(10)),child: Image.asset('assets/images/404.png')))),
                errorWidget: (context, url, error) =>  Container(width: 120,height: 100,child: Image.asset("assets/icon/user-removebg-preview.png",fit: BoxFit.cover,)),
              ),
            ),
          ),



          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4.0,bottom: 4),
                  child: SizedBox(
                    //width: 70,
                    child: Container(
                      alignment: Alignment.center,
                      child: TextCustomerPostDescription(
                        titre: "@${widget.user.pseudo}",
                        fontSize: 15,
                        couleur: ConstColors.textColors,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4.0,bottom: 4),
                  child: SizedBox(
                    //width: 70,
                    child: Container(
                      alignment: Alignment.center,
                      child: TextCustomerPostDescription(
                        titre: "${widget.user.abonnes}",
                        fontSize: 15,
                        couleur: ConstColors.textColors,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4.0,bottom: 4),
                  child: SizedBox(
                    //width: 70,
                    child: Container(
                      alignment: Alignment.center,
                      child: TextCustomerPostDescription(
                        titre: "${taux.toStringAsFixed(2)} %",
                        fontSize: 15,
                        couleur: ConstColors.textColors,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [

              RatingStars(
                rating: 5*widget.user.popularite!,
                editable: true,
                iconSize: 35,
                color: Colors.green,
              ),
              LikeButton(

                isLiked: false,
                size: 50,
                circleColor:
                CircleColor(start: Color(0xff00ddff), end: Color(0xff0099cc)),
                bubblesColor: BubblesColor(
                  dotPrimaryColor: Color(0xff3b9ade),
                  dotSecondaryColor: Color(0xff027f19),
                ),
                countPostion: CountPostion.bottom,
                likeBuilder: (bool isLiked) {
                  return Icon(
                    !isLiked ?AntDesign.like1:AntDesign.like1,
                    color: !isLiked ? Colors.black38 : Colors.blue,
                    size: 35,
                  );
                },
               // likeCount: 30,
                countBuilder: (int? count, bool isLiked, String text) {
                  var color = isLiked ? Colors.black : Colors.black;
                  Widget result;
                  if (count == 0) {
                    result = Text(
                      "0",textAlign: TextAlign.center,
                      style: TextStyle(color: color),
                    );
                  } else
                    result = Text(
                      text,
                      style: TextStyle(color: color),
                    );
                  return result;
                },

              ),



            ],
          )

        ],
      ),
    );
  }
}
