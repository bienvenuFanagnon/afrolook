import 'dart:async';
import 'dart:math';

import 'package:afrotok/pages/home/postMenu.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flash/flash.dart';
import 'package:flash/flash_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:afrotok/constant/constColors.dart';
import 'package:afrotok/constant/iconGradient.dart';
import 'package:afrotok/constant/logo.dart';
import 'package:afrotok/constant/sizeText.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/providers/userProvider.dart';
import 'package:afrotok/services/api.dart';
import 'package:flutter/material.dart';
import 'package:badges/badges.dart' as badges;
import 'package:flutter/services.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:intl/intl.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:popover_gtk/popover_gtk.dart';
import 'package:popup_menu_plus/popup_menu_plus.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:stories_for_flutter/stories_for_flutter.dart';
import '../../constant/listItemsCarousel.dart';
import '../../constant/textCustom.dart';
import '../../models/chatmodels/message.dart';
import '../../providers/authProvider.dart';

class DetailsPost extends StatefulWidget {
  final Post post;
  const DetailsPost({super.key, required this.post});

  @override
  State<DetailsPost> createState() => _DetailsPostState();
}

class _DetailsPostState extends State<DetailsPost> {

  String token='';
  bool dejaVuPub=true;

  GlobalKey btnKey = GlobalKey();
  GlobalKey btnKey2 = GlobalKey();
  GlobalKey btnKey3 = GlobalKey();
  GlobalKey btnKey4 = GlobalKey();
  final _formKey = GlobalKey<FormState>();
  GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  late UserProvider userProvider =
  Provider.of<UserProvider>(context, listen: false);
  int imageIndex=0;
  late PostProvider postProvider =
  Provider.of<PostProvider>(context, listen: false);
  TextEditingController commentController =TextEditingController();
  String formaterDateTime2(DateTime dateTime) {
    DateTime now = DateTime.now();

    if (dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day) {
      // Si la date est aujourd'hui, afficher seulement l'heure et la minute
      return DateFormat.Hm().format(dateTime);
    } else {
      // Sinon, afficher la date complète
      return DateFormat.yMd().add_Hms().format(dateTime);
    }
  }

  String formaterDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays < 1) {
      // Si c'est le même jour
      if (difference.inHours < 1) {
        // Si moins d'une heure
        if (difference.inMinutes < 1) {
          return "publié il y a quelques secondes";
        } else {
          return "publié il y a ${difference.inMinutes} minutes";
        }
      } else {
        return "publié il y a ${difference.inHours} heures";
      }
    } else if (difference.inDays < 7) {
      // Si la semaine n'est pas passée
      return "publié ${difference.inDays} jours plus tôt";
    } else {
      // Si le jour est passé
      return "publié depuis ${DateFormat('dd MMMM yyyy').format(dateTime)}";
    }
  }
  void _showModalDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Menu d\'options'),
          content: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                ListTile(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  leading: Icon(Icons.flag,color: Colors.blueGrey,),
                  title: Text('Signaler',),
                ),
                ListTile(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  leading: Icon(Icons.edit,color: Colors.blue,),
                  title: Text('Modifier'),
                ),
                ListTile(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  leading: Icon(Icons.delete,color: Colors.red,),
                  title: Text('Supprimer'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    return  Scaffold(
        appBar: AppBar(
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
            children: <Widget>[

              Container(
                child:widget.post.type==PostType.PUB.name?
                StatefulBuilder(

                    builder: (BuildContext context, StateSetter setStateImages) {
                      return Padding(

                        padding: const EdgeInsets.all(5.0),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [

                                    Row(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(right: 8.0),
                                          child: CircleAvatar(
                                            backgroundImage: NetworkImage(
                                                '${widget.post.entrepriseData!.urlImage!}'),

                                          ),
                                        ),
                                        SizedBox(
                                          height: 2,
                                        ),
                                        Row(
                                          children: [
                                            Column(
                                              children: [
                                                SizedBox(
                                                  //width: 100,
                                                  child: TextCustomerUserTitle(
                                                    titre: "#${widget.post.entrepriseData!.titre!}",
                                                    fontSize: SizeText.homeProfileTextSize,
                                                    couleur: ConstColors.textColors,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                TextCustomerUserTitle(
                                                  titre: "${widget.post.entrepriseData!.suivi!} suivi(s)",
                                                  fontSize: 10,
                                                  couleur: ConstColors.textColors,
                                                  fontWeight: FontWeight.w400,
                                                ),

                                              ],
                                            ),

                                            /*
                                    IconButton(
                                        onPressed: () {},
                                        icon: Icon(
                                          Icons.add_circle_outlined,
                                          size: 20,
                                          color: ConstColors.regIconColors,
                                        )),

                                     */
                                          ],
                                        ),
                                      ],
                                    ),
                                    SizedBox(width: 20,),
                                    Icon(Entypo.arrow_long_right,color: Colors.green,),
                                    SizedBox(width: 20,),
                                    Row(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(right: 8.0),
                                          child: CircleAvatar(
                                            backgroundImage: NetworkImage(
                                                '${widget.post.user!.imageUrl!}'),
                                          ),
                                        ),
                                        SizedBox(
                                          height: 2,
                                        ),
                                        Row(
                                          children: [
                                            Column(
                                              mainAxisAlignment: MainAxisAlignment.start,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                SizedBox(
                                                  //width: 100,
                                                  child: TextCustomerUserTitle(
                                                    titre: "@${widget.post.user!.pseudo!}",
                                                    fontSize: SizeText.homeProfileTextSize,
                                                    couleur: ConstColors.textColors,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                TextCustomerUserTitle(
                                                  titre: "${widget.post.user!.abonnes!} abonné(s)",
                                                  fontSize: 10,
                                                  couleur: ConstColors.textColors,
                                                  fontWeight: FontWeight.w400,
                                                ),

                                              ],
                                            ),

                                            /*
                                IconButton(
                                    onPressed: () {},
                                    icon: Icon(
                                      Icons.add_circle_outlined,
                                      size: 20,
                                      color: ConstColors.regIconColors,
                                    )),

                                 */
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                IconButton(
                                    onPressed: _showModalDialog,
                                    icon: Icon(
                                      Icons.more_horiz,
                                      size: 30,
                                      color: ConstColors.blackIconColors,
                                    )),
                              ],
                            ),
                            SizedBox(
                              height: 5,
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                children: [
                                  Icon(Entypo.network,size: 15,),
                                  SizedBox(width: 10,),
                                  TextCustomerUserTitle(
                                    titre: "publicité",
                                    fontSize: SizeText.homeProfileTextSize,
                                    couleur: Colors.green,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              height: 5,
                            ),
                            Align(
                              alignment: Alignment.topLeft,
                              child: SizedBox(
                                width: width*0.9,
                                //height: 50,
                                child: Container(
                                  alignment: Alignment.centerLeft,
                                  child: TextCustomerPostDescription(
                                    titre:
                                    "${widget.post.description}",
                                    fontSize: SizeText.homeProfileTextSize,
                                    couleur: ConstColors.textColors,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              height: 5,
                            ),
                            Align(
                              alignment: Alignment.topLeft,
                              child: TextCustomerPostDescription(
                                titre: "${formaterDateTime(DateTime.fromMicrosecondsSinceEpoch(widget.post.createdAt!))}",
                                fontSize: SizeText.homeProfileDateTextSize,
                                couleur: ConstColors.textColors,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(
                              height: 5,
                            ),
                            widget.post!.images==null? Container():  Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [

                                  for(int i=0;i<widget.post!.images!.length;i++)
                                    TextButton(onPressed: ()
                                    {
                                      setStateImages(() {
                                        imageIndex=i;
                                      });

                                    }, child:   Container(
                                      width: 100,
                                      height: 50,

                                      child: ClipRRect(
                                        borderRadius: BorderRadius.all(Radius.circular(10)),
                                        child: Container(

                                          child: CachedNetworkImage(

                                            fit: BoxFit.cover,
                                            imageUrl: '${widget.post!.images![i]}',
                                            progressIndicatorBuilder: (context, url, downloadProgress) =>
                                            //  LinearProgressIndicator(),

                                            Skeletonizer(
                                                child: SizedBox(width: 400,height: 450, child:  ClipRRect(
                                                    borderRadius: BorderRadius.all(Radius.circular(10)),child: Image.asset('assets/images/404.png')))),
                                            errorWidget: (context, url, error) =>  Skeletonizer(child: Container(width: 400,height: 450,child: Image.asset("assets/images/404.png",fit: BoxFit.cover,))),
                                          ),
                                        ),
                                      ),
                                    ),)
                                ],
                              ),
                            ),
                            Container(
                              width: width,
                              height: height*0.5,

                              child: ClipRRect(
                                borderRadius: BorderRadius.all(Radius.circular(5)),
                                child: Container(

                                  child: CachedNetworkImage(

                                    fit: BoxFit.fill,
                                    imageUrl: '${widget.post!.images==null?'':widget.post!.images!.isEmpty?'':widget.post!.images![imageIndex]}',
                                    progressIndicatorBuilder: (context, url, downloadProgress) =>
                                    //  LinearProgressIndicator(),

                                    Skeletonizer(
                                        child: SizedBox(width: 400,height: 450, child:  ClipRRect(
                                            borderRadius: BorderRadius.all(Radius.circular(10)),child: Image.asset('assets/images/404.png')))),
                                    errorWidget: (context, url, error) =>  Skeletonizer(child: Container(width: 400,height: 450,child: Image.asset("assets/images/404.png",fit: BoxFit.cover,))),
                                  ),
                                ),
                              ),
                            ),





                            SizedBox(
                              height: 10,
                            ),
                            Divider(
                              height: 3,
                            )

                          ],
                        ),
                      );
                    }
                ): StatefulBuilder(
                    builder: (BuildContext context, StateSetter setStateImages) {
                      return Padding(
                        padding: const EdgeInsets.all(5.0),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8.0),
                                      child: CircleAvatar(
                                        backgroundImage: NetworkImage(
                                            '${widget.post.user!.imageUrl!}'),
                                      ),
                                    ),
                                    SizedBox(
                                      height: 2,
                                    ),
                                    Row(
                                      children: [
                                        Column(


                                          children: [
                                            SizedBox(
                                              //width: 100,
                                              child: TextCustomerUserTitle(
                                                titre: "@${widget.post.user!.pseudo!}",
                                                fontSize: SizeText.homeProfileTextSize,
                                                couleur: ConstColors.textColors,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            TextCustomerUserTitle(
                                              titre: "${widget.post.user!.abonnes!} abonné(s)",
                                              fontSize: SizeText.homeProfileTextSize,
                                              couleur: ConstColors.textColors,
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ],
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                        ),


                                      ],
                                    ),
                                  ],
                                ),
                                IconButton(
                                    onPressed: _showModalDialog,
                                    icon: Icon(
                                      Icons.more_horiz,
                                      size: 30,
                                      color: ConstColors.blackIconColors,
                                    )),
                              ],
                            ),
                            SizedBox(
                              height: 5,
                            ),
                            Align(
                              alignment: Alignment.topLeft,
                              child: SizedBox(
                                width: width*0.9,                              //height: 50,
                                child: Container(
                                  alignment: Alignment.centerLeft,
                                  child: TextCustomerPostDescription(
                                    titre:
                                    "${widget.post.description}",
                                    fontSize: SizeText.homeProfileTextSize,
                                    couleur: ConstColors.textColors,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              height: 5,
                            ),
                            Align(
                              alignment: Alignment.topLeft,
                              child: TextCustomerPostDescription(
                                titre: "${formaterDateTime(DateTime.fromMicrosecondsSinceEpoch(widget.post.createdAt!))}",
                                fontSize: SizeText.homeProfileDateTextSize,
                                couleur: ConstColors.textColors,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(
                              height: 5,
                            ),
                            widget.post!.images==null? Container():  Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [

                                  for(int i=0;i<widget.post!.images!.length;i++)
                                    TextButton(onPressed: ()
                                    {
                                      setStateImages(() {
                                        imageIndex=i;
                                      });

                                    }, child:   Container(
                                      width: 100,
                                      height: 50,

                                      child: ClipRRect(
                                        borderRadius: BorderRadius.all(Radius.circular(10)),
                                        child: Container(

                                          child: CachedNetworkImage(

                                            fit: BoxFit.cover,
                                            imageUrl: '${widget.post!.images![i]}',
                                            progressIndicatorBuilder: (context, url, downloadProgress) =>
                                            //  LinearProgressIndicator(),

                                            Skeletonizer(
                                                child: SizedBox(width: 400,height: 450, child:  ClipRRect(
                                                    borderRadius: BorderRadius.all(Radius.circular(10)),child: Image.asset('assets/images/404.png')))),
                                            errorWidget: (context, url, error) =>  Skeletonizer(child: Container(width: 400,height: 450,child: Image.asset("assets/images/404.png",fit: BoxFit.cover,))),
                                          ),
                                        ),
                                      ),
                                    ),)
                                ],
                              ),
                            ),
                            Container(
                              width: width,
                              height: height*0.5,

                              child: ClipRRect(
                                borderRadius: BorderRadius.all(Radius.circular(5)),
                                child: Container(

                                  child: CachedNetworkImage(

                                    fit: BoxFit.fill,
                                    imageUrl: '${widget.post!.images==null?'':widget.post!.images![imageIndex]}',
                                    progressIndicatorBuilder: (context, url, downloadProgress) =>
                                    //  LinearProgressIndicator(),

                                    Skeletonizer(
                                        child: SizedBox(width: 400,height: 450, child:  ClipRRect(
                                            borderRadius: BorderRadius.all(Radius.circular(10)),child: Image.asset('assets/images/404.png')))),
                                    errorWidget: (context, url, error) =>  Skeletonizer(child: Container(width: 400,height: 450,child: Image.asset("assets/images/404.png",fit: BoxFit.cover,))),
                                  ),
                                ),
                              ),
                            ),


                            SizedBox(
                              height: 10,
                            ),
                            Divider(
                              height: 3,
                            )

                          ],
                        ),
                      );
                    }
                ),
              ),

            ]
                  ),
          ),
        ),
    );
  }
}
