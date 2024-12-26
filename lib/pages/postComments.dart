import 'dart:async';
import 'dart:math';

import 'package:afrotok/pages/home/postMenu.dart';
import 'package:afrotok/pages/userPosts/hashtag/textHashTag/views/view_models/home_view_model.dart';
import 'package:afrotok/pages/userPosts/hashtag/textHashTag/views/view_models/search_view_model.dart';
import 'package:afrotok/pages/userPosts/hashtag/textHashTag/views/widgets/comment_text_field.dart';
import 'package:afrotok/pages/userPosts/hashtag/textHashTag/views/widgets/search_result_overlay.dart';
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
import 'package:flutter_list_view/flutter_list_view.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:fluttertagger/fluttertagger.dart';
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
import 'component/consoleWidget.dart';

class PostComments extends StatefulWidget {
  final Post post;
  const PostComments({super.key, required this.post});

  @override
  State<PostComments> createState() => _PostCommentsState();
}

class _PostCommentsState extends State<PostComments> with TickerProviderStateMixin{
  String token = '';
  bool dejaVuPub = true;

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
  int imageIndex = 0;
  PostComment commentSelectedToReply = PostComment();
  late PostProvider postProviders =
      Provider.of<PostProvider>(context, listen: false);
  TextEditingController commentController = TextEditingController();
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

   _showPostMenuModalDialog(Post post) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Menu'),
          content: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                Visibility(
                  visible: post.user!.id != authProvider.loginUserData.id,
                  child: ListTile(
                    onTap: () async {
                      post.status = PostStatus.SIGNALER.name;
                      await postProviders.updateVuePost(post, context).then(
                            (value) {
                          if (value) {
                            SnackBar snackBar = SnackBar(
                              content: Text(
                                'Post signalé !',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.green),
                              ),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(snackBar);
                          } else {
                            SnackBar snackBar = SnackBar(
                              content: Text(
                                'échec !',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.red),
                              ),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(snackBar);
                          }
                          Navigator.pop(context);
                        },
                      );
                      setState(() {});
                    },
                    leading: Icon(
                      Icons.flag,
                      color: Colors.blueGrey,
                    ),
                    title: Text(
                      'Signaler',
                    ),
                  ),
                ),
                /*
                ListTile(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  leading: Icon(Icons.edit,color: Colors.blue,),
                  title: Text('Modifier'),
                ),

                 */
                Visibility(
                  visible: post.user!.id == authProvider.loginUserData.id,
                  child: ListTile(
                    onTap: () async {
                      if (authProvider.loginUserData.role == UserRole.ADM.name) {
                        post.status = PostStatus.NONVALIDE.name;
                        await postProviders.updateVuePost(post, context).then(
                              (value) {
                            if (value) {
                              SnackBar snackBar = SnackBar(
                                content: Text(
                                  'Post bloqué !',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.green),
                                ),
                              );
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(snackBar);
                            } else {
                              SnackBar snackBar = SnackBar(
                                content: Text(
                                  'échec !',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.red),
                                ),
                              );
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(snackBar);
                            }
                          },
                        );
                      } else if (post.type == PostType.POST.name) {
                        if (post.user!.id == authProvider.loginUserData.id) {
                          post.status = PostStatus.SUPPRIMER.name;
                          await postProviders.updateVuePost(post, context).then(
                                (value) {
                              if (value) {
                                SnackBar snackBar = SnackBar(
                                  content: Text(
                                    'Post supprimé !',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.green),
                                  ),
                                );
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(snackBar);
                              } else {
                                SnackBar snackBar = SnackBar(
                                  content: Text(
                                    'échec !',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.red),
                                  ),
                                );
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(snackBar);
                              }
                            },
                          );
                        }
                      }

                      setState(() {
                        Navigator.pop(context);
                      });
                    },
                    leading: Icon(
                      Icons.delete,
                      color: Colors.red,
                    ),
                    title: authProvider.loginUserData.role == UserRole.ADM.name
                        ? Text('Bloquer')
                        : Text('Supprimer'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  _showCommentMenuModalDialog(PostComment postComment) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Menu'),
          content: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                // Visibility(
                //   visible: postComment.user!.id != authProvider.loginUserData.id,
                //   child: ListTile(
                //     onTap: () async {
                //       postComment.status = PostStatus.SIGNALER.name;
                //       await postProviders.updateComment(postComment).then(
                //             (value) {
                //           if (value) {
                //             SnackBar snackBar = SnackBar(
                //               content: Text(
                //                 'Post signalé !',
                //                 textAlign: TextAlign.center,
                //                 style: TextStyle(color: Colors.green),
                //               ),
                //             );
                //             ScaffoldMessenger.of(context).showSnackBar(snackBar);
                //           } else {
                //             SnackBar snackBar = SnackBar(
                //               content: Text(
                //                 'échec !',
                //                 textAlign: TextAlign.center,
                //                 style: TextStyle(color: Colors.red),
                //               ),
                //             );
                //             ScaffoldMessenger.of(context).showSnackBar(snackBar);
                //           }
                //           Navigator.pop(context);
                //         },
                //       );
                //       setState(() {});
                //     },
                //     leading: Icon(
                //       Icons.flag,
                //       color: Colors.blueGrey,
                //     ),
                //     title: Text(
                //       'Signaler',
                //     ),
                //   ),
                // ),
                /*
                ListTile(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  leading: Icon(Icons.edit,color: Colors.blue,),
                  title: Text('Modifier'),
                ),

                 */
                Visibility(
                  visible: postComment.user!.id == authProvider.loginUserData.id||authProvider.loginUserData.role == UserRole.ADM.name,
                  child: ListTile(
                    onTap: () async {
                      if (authProvider.loginUserData.role == UserRole.ADM.name) {
                        postComment.status = PostStatus.SUPPRIMER.name;
                        await postProviders.updateComment(postComment).then(
                              (value) {
                            if (value) {
                              SnackBar snackBar = SnackBar(
                                content: Text(
                                  'commentaire supprimé !',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.green),
                                ),
                              );
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(snackBar);
                              setState(() {

                              });
                            } else {
                              SnackBar snackBar = SnackBar(
                                content: Text(
                                  'échec !',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.red),
                                ),
                              );
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(snackBar);
                            }
                          },
                        );
                      } else
                        if (postComment.user!.id == authProvider.loginUserData.id) {
                          postComment.status = PostStatus.SUPPRIMER.name;
                          await postProviders.updateComment(postComment).then(
                                (value) {
                              if (value) {
                                SnackBar snackBar = SnackBar(
                                  content: Text(
                                    'commentaire supprimé !',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.green),
                                  ),
                                );
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(snackBar);
                                setState(() {

                                });
                              } else {
                                SnackBar snackBar = SnackBar(
                                  content: Text(
                                    'échec !',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.red),
                                  ),
                                );
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(snackBar);
                              }
                            },
                          );
                        }


                      setState(() {
                        Navigator.pop(context);
                      });
                    },
                    leading: Icon(
                      Icons.delete,
                      color: Colors.red,
                    ),
                    title: authProvider.loginUserData.role == UserRole.ADM.name
                        // ? Text('Bloquer')
                        ? Text('Supprimer')
                        : Text('Supprimer'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  _showResponseCommentMenuModalDialog(PostComment postComment,ResponsePostComment response) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Menu'),
          content: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                // Visibility(
                //   visible: postComment.user!.id != authProvider.loginUserData.id,
                //   child: ListTile(
                //     onTap: () async {
                //       postComment.status = PostStatus.SIGNALER.name;
                //       await postProviders.updateComment(postComment).then(
                //             (value) {
                //           if (value) {
                //             SnackBar snackBar = SnackBar(
                //               content: Text(
                //                 'Post signalé !',
                //                 textAlign: TextAlign.center,
                //                 style: TextStyle(color: Colors.green),
                //               ),
                //             );
                //             ScaffoldMessenger.of(context).showSnackBar(snackBar);
                //           } else {
                //             SnackBar snackBar = SnackBar(
                //               content: Text(
                //                 'échec !',
                //                 textAlign: TextAlign.center,
                //                 style: TextStyle(color: Colors.red),
                //               ),
                //             );
                //             ScaffoldMessenger.of(context).showSnackBar(snackBar);
                //           }
                //           Navigator.pop(context);
                //         },
                //       );
                //       setState(() {});
                //     },
                //     leading: Icon(
                //       Icons.flag,
                //       color: Colors.blueGrey,
                //     ),
                //     title: Text(
                //       'Signaler',
                //     ),
                //   ),
                // ),
                /*
                ListTile(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  leading: Icon(Icons.edit,color: Colors.blue,),
                  title: Text('Modifier'),
                ),

                 */
                Visibility(
                  visible: postComment.user!.id == authProvider.loginUserData.id||authProvider.loginUserData.role == UserRole.ADM.name,
                  child: ListTile(
                    onTap: () async {
                      if (authProvider.loginUserData.role == UserRole.ADM.name) {
                        response.status = PostStatus.SUPPRIMER.name;
                     int indexResponse=   postComment.responseComments!.indexOf(response);
                        postComment.responseComments!.elementAt(indexResponse).status= PostStatus.SUPPRIMER.name;


                        await postProviders.updateComment(postComment).then(
                              (value) {
                            if (value) {
                              SnackBar snackBar = SnackBar(
                                content: Text(
                                  'commentaire supprimé !',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.green),
                                ),
                              );
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(snackBar);
                            } else {
                              SnackBar snackBar = SnackBar(
                                content: Text(
                                  'échec !',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.red),
                                ),
                              );
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(snackBar);
                            }
                          },
                        );
                      } else
                      if (postComment.user!.id == authProvider.loginUserData.id) {
                        response.status = PostStatus.SUPPRIMER.name;
                        int indexResponse=   postComment.responseComments!.indexOf(response);
                        // postComment.responseComments![indexResponse]=response;
                        postComment.responseComments!.elementAt(indexResponse).status= PostStatus.SUPPRIMER.name;

                        await postProviders.updateComment(postComment).then(
                              (value) {
                            if (value) {
                              SnackBar snackBar = SnackBar(
                                content: Text(
                                  'commentaire supprimé !',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.green),
                                ),
                              );
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(snackBar);
                            } else {
                              SnackBar snackBar = SnackBar(
                                content: Text(
                                  'échec !',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.red),
                                ),
                              );
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(snackBar);
                            }
                          },
                        );
                      }


                      setState(() {
                        Navigator.pop(context);
                      });
                    },
                    leading: Icon(
                      Icons.delete,
                      color: Colors.red,
                    ),
                    title: authProvider.loginUserData.role == UserRole.ADM.name
                    // ? Text('Bloquer')
                        ? Text('Supprimer')
                        : Text('Supprimer'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }







  late bool replying = false;
  late UserData commentRecever = UserData();
  late String replyingTo = '';
  late String replyUser_pseudo = '';
  late String replyUser_id = '';
  //late List<Widget> actions;
  late TextEditingController _textController = TextEditingController();
  Duration duration = new Duration();
  Duration position = new Duration();
  bool isPlaying = false;
  bool isLoading = false;
  bool isPause = false;
  bool sendMessageTap = false;
  double siveBoxLastmessage = 10;
  String formatNumber(int number) {
    if (number < 1000) {
      return number.toString();
    } else if (number < 1000000) {
      return "${number / 1000} k";
    } else if (number < 1000000000) {
      return "${number / 1000000} m";
    } else {
      return "${number / 1000000000} b";
    }
  }

  late AnimationController _animationController;
  late Animation<Offset> _animation;

  double overlayHeight = 380;

  late final homeViewModel = HomeViewModel();
  late final _controller = FlutterTaggerController(
    //Initial text value with tag is formatted internally
    //following the construction of FlutterTaggerController.
    //After this controller is constructed, if you
    //wish to update its text value with raw tag string,
    //call (_controller.formatTags) after that.
    text:
    "",
  );
  late final _focusNode = FocusNode();

  void _focusListener() {
    if (!_focusNode.hasFocus) {
      _controller.dismissOverlay();
    }
  }
  // ScrollController _controller = ScrollController();
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  /// Declare
  FlutterListViewController fluttercontroller = FlutterListViewController();
  // FocusNode _focusNode = FocusNode();

  Widget commentAndResponseListWidget(
    List<PostComment> pcms,
    double width,
      double height,
  ) {
    bool isExpandedState=false;

    return SingleChildScrollView(

      child: StatefulBuilder(
          builder: (BuildContext context, StateSetter setStatep) {
            return       Column(
              children: [
                for(PostComment pcm in pcms!)
                ExpansionTile(
                  trailing: Container(
                      child: Padding(
                        padding: const EdgeInsets.all(1.0),
                        child: Text('${formatNumber(pcm.responseComments!.length)}',style: TextStyle(color: Colors.red),),
                      )),

                  title: ListTile(

                    leading: Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: CircleAvatar(
                        radius: 12,
                        backgroundImage:
                        NetworkImage('${pcm.user!.imageUrl}'),
                        onBackgroundImageError: (exception, stackTrace) => AssetImage('assets/images/404.png'),
                      ),
                    ),
                    title: SizedBox(
                      width: 100,
                      child: TextCustomerUserTitle(
                        titre: "@${pcm.user!.pseudo!}",
                        fontSize: SizeText.homeProfileTextSize,
                        couleur: ConstColors.textColors,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: width,
                          //height: 100,

                          child:Row(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    commentSelectedToReply = PostComment();
                                    commentSelectedToReply = pcm;
                                    // commentRecever=pcm.user!;
                                    replyingTo = "@${pcm.user!.pseudo}";
                                    // replyUser_id=pcm.user!.id!;
                                    // replyUser_pseudo=pcm.user!.pseudo!;
                                    replying = true;
                                  });
                                },

                                child: SizedBox(
                                  width: width * 0.2,
                                  child: TextCustomerPostDescription(
                                    titre: "${pcm.status==PostStatus.SUPPRIMER.name?"message supprimé":pcm.message!}",
                                    fontSize: SizeText.homeProfileTextSize,
                                    couleur: pcm.status==PostStatus.SUPPRIMER.name?Colors.red:ConstColors.textColors,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  IconButton(onPressed: () {
                                    setState(() {
                                      commentSelectedToReply = PostComment();
                                      commentSelectedToReply = pcm;
                                      commentRecever=commentSelectedToReply.user!;

                                      replyUser_id=commentSelectedToReply.user!.id!;
                                      replyUser_pseudo=commentSelectedToReply.user!.pseudo!;

                                      replyingTo = "@${commentSelectedToReply.user!.pseudo}";
                                      replying = true;
                                    });


                                  }, icon: Icon(Icons.reply_all,color: Colors.green,size: 15,)),
                                  IconButton(onPressed: () {
                                    setState(() {

                                      _showCommentMenuModalDialog(pcm);

                                    });


                                  }, icon: Icon(Icons.more_horiz,color: Colors.green,size: 15,)),

                                ],
                              )

                            ],
                          ),
                        ),
                        Text("${formaterDateTime(DateTime.fromMicrosecondsSinceEpoch(pcm.createdAt!))}",style: TextStyle(fontSize: 8,fontWeight: FontWeight.bold),),
                      ],
                    ),
                    // trailing: Container(
                    //     child: Padding(
                    //       padding: const EdgeInsets.all(1.0),
                    //       child: Text('${formatNumber(pcm.responseAbonnements!.length)}',style: TextStyle(color: Colors.red),),
                    //     )),
                    /*
                      trailing: Align(
                        alignment: Alignment.centerRight,
                        child: TextCustomerPostDescription(
                          titre:
                          "${formaterDateTime(DateTime.fromMicrosecondsSinceEpoch(pcm.createdAt!))}",
                          fontSize: SizeText.textDatePostSize,
                          couleur: ConstColors.textColors,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                       */
                  ),
                  children: [
                    for(ResponsePostComment rpc in pcm.responseComments!)
                      Padding(
                        padding: const EdgeInsets.only(left: 30.0),
                        child: ListTile(

                          leading: Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Container(
                              decoration: BoxDecoration(
                                  border: Border.all(color: Colors.green),
                                  borderRadius: BorderRadius.all(Radius.circular(200))
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(3.0),
                                child: CircleAvatar(

                                  backgroundColor: Colors.green,
                                  radius: 8,
                                  backgroundImage:
                                  NetworkImage('${rpc!.user_logo_url}'),
                                ),
                              ),
                            ),
                          ),
                          title: SizedBox(
                            width: 100,
                            child: TextCustomerUserTitle(
                              titre: "@${rpc!.user_pseudo}",
                              fontSize: SizeText.homeProfileTextSize,
                              couleur: ConstColors.textColors,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: width * 0.8,
                                //height: 100,

                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: width * 0.3,
                                      child: TextCustomerPostDescription(
                                        titre: "${rpc.status==PostStatus.SUPPRIMER.name?"Supprimé":rpc.message!}",
                                        fontSize: SizeText.homeProfileTextSize,
                                        couleur: rpc.status==PostStatus.SUPPRIMER.name?Colors.red:ConstColors.textColors,

                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),

                                    Row(
                                      children: [
                                        IconButton(onPressed: () {
                                          printVm("****** response pcm selected");

                                          setState(() {
                                            // printVm("****** response pcm **** : ${pcm.toJson()}");

                                            commentSelectedToReply = PostComment();
                                            commentSelectedToReply = pcm;
                                            commentRecever=pcm.user!;

                                            printVm('rpc data ${rpc.toJson()}');
                                            replyUser_id=rpc.user_id!;
                                            replyUser_pseudo=pcm.user!.pseudo!;

                                            replyingTo = "@${rpc!.user_pseudo}";
                                            replying = true;
                                          });


                                        }, icon: Icon(Icons.reply_all,color: Colors.green,size: 14,)),
                                        IconButton(onPressed: () {

                                          _showResponseCommentMenuModalDialog(pcm,rpc);



                                        }, icon: Icon(Icons.more_horiz,color: Colors.green,size: 14,)),
                                      ],
                                    )

                                  ],
                                ),
                              ),
                              Text("${formaterDateTime(DateTime.fromMicrosecondsSinceEpoch(rpc.createdAt!))}",style: TextStyle(fontSize: 7,fontWeight: FontWeight.bold),),

                            ],
                          ),
                          /*
                            trailing: Align(
                              alignment: Alignment.centerRight,
                              child: TextCustomerPostDescription(
                                titre:
                                "${formaterDateTime(DateTime.fromMicrosecondsSinceEpoch(pcm.responseAbonnements![index]!.createdAt!))}",
                                fontSize: SizeText.textDatePostSize,
                                couleur: ConstColors.textColors,
                                fontWeight: FontWeight.w500,
                              ),
                            ),

                             */
                        ),
                      ),
                  ],
                ),

              ],
            );
          }
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_focusListener);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    _animation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _focusNode.removeListener(_focusListener);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var insets = MediaQuery.of(context).viewInsets;
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,


        child: Consumer<PostProvider>(builder: (context, postPro, _) {
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[

              Container(
                child: StatefulBuilder(builder:
                        (BuildContext context, StateSetter setStateImages) {
                        return Padding(
                          padding: const EdgeInsets.all(5.0),
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Align(
                                    //   alignment: Alignment.centerLeft,
                                    //   child: IconButton(onPressed: () {
                                    //
                                    //   }, icon: Icon(Icons.arrow_back_sharp,color: Colors.green,)),
                                    // ),
                                    Row(
                                      children: [
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(right: 8.0),
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
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              crossAxisAlignment: CrossAxisAlignment.start,
        
                                              children: [
                                                SizedBox(
                                                  //width: 100,
                                                  child: TextCustomerUserTitle(
                                                    titre:
                                                        "@${widget.post.user!.pseudo!}",
                                                    fontSize: SizeText
                                                        .homeProfileTextSize,
                                                    couleur:
                                                        ConstColors.textColors,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                TextCustomerUserTitle(
                                                  titre:
                                                      "${widget.post.user!.abonnes!} abonné(s)",
                                                  fontSize: SizeText
                                                      .homeProfileTextSize,
                                                  couleur: ConstColors.textColors,
                                                  fontWeight: FontWeight.w400,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    IconButton(
                                        onPressed: () {
                                          _showPostMenuModalDialog(widget.post);
                                        },
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
                                    width: width * 0.9,
                                    height: 80,
                                    child: Container(
                                      alignment: Alignment.centerLeft,
                                      child: TextCustomerPostDescription(
                                        titre: "${widget.post.description}",
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
                                    titre:
                                        "${formaterDateTime(DateTime.fromMicrosecondsSinceEpoch(widget.post.createdAt!))}",
                                    fontSize: SizeText.homeProfileDateTextSize,
                                    couleur: ConstColors.textColors,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(
                                  height: 5,
                                ),
                                widget.post!.images == null
                                    ? Container()
                                    : Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            for (int i = 0;
                                                i < widget.post!.images!.length;
                                                i++)
                                              TextButton(
                                                onPressed: () {
                                                  setStateImages(() {
                                                    imageIndex = i;
                                                  });
                                                },
                                                child: Container(
                                                  width: 100,
                                                  height: 50,
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.all(
                                                            Radius.circular(10)),
                                                    child: Container(
                                                      child: CachedNetworkImage(
                                                        fit: BoxFit.cover,
                                                        imageUrl:
                                                            '${widget.post!.images![i]}',
                                                        progressIndicatorBuilder: (context,
                                                                url,
                                                                downloadProgress) =>
                                                            //  LinearProgressIndicator(),
        
                                                            Skeletonizer(
                                                                child: SizedBox(
                                                                    width: 400,
                                                                    height: 450,
                                                                    child: ClipRRect(
                                                                        borderRadius:
                                                                            BorderRadius.all(Radius.circular(
                                                                                10)),
                                                                        child: Image
                                                                            .asset(
                                                                                'assets/images/404.png')))),
                                                        errorWidget: (context,
                                                                url, error) =>
                                                            Skeletonizer(
                                                                child: Container(
                                                                    width: 400,
                                                                    height: 450,
                                                                    child: Image
                                                                        .asset(
                                                                      "assets/images/404.png",
                                                                      fit: BoxFit
                                                                          .cover,
                                                                    ))),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              )
                                          ],
                                        ),
                                      ),
                                SizedBox(
                                  height: 10,
                                ),
                                Provider<PostProvider>(
                                  create: (context) => PostProvider(),
                                  child: SizedBox(
                                    height:widget.post!.images != null? height * 0.44:height * 0.45,
                                    width: width,
                                    child: FutureBuilder<List<PostComment>>(
                                        future: postProviders
                                            .getPostCommentsNoStream(
                                            widget.post),
                                        builder: (BuildContext context,
                                            AsyncSnapshot snapshot) {
                                          if (snapshot.hasData) {
                                            return commentAndResponseListWidget(
                                                snapshot.data!,
                                                width,height);
                                          } else if (snapshot.hasError) {
                                            return Icon(Icons.error_outline);
                                          } else {
                                            return Center(child: Container( width: 50, height: 50, child: CircularProgressIndicator()));
                                          }
                                        }),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
              ),
              // Align(
              //   alignment: Alignment.bottomCenter,
              //   child: Container(
              //     //height: 50,
              //     child: Column(
              //       mainAxisAlignment: MainAxisAlignment.end,
              //       children: [
              //         replying
              //             ? Container(
              //             width: width * 0.8,
              //             height: 70,
              //             color: const Color(0xffF4F4F5),
              //             padding: const EdgeInsets.symmetric(
              //               vertical: 8,
              //               horizontal: 16,
              //             ),
              //             child: Row(
              //               children: [
              //                 Icon(
              //                   Icons.reply,
              //                   color: Colors.blue,
              //                   size: 24,
              //                 ),
              //                 Expanded(
              //                   child: Container(
              //                     child: Text(
              //                       'Re : ' + replyingTo,
              //                       overflow: TextOverflow.ellipsis,
              //                     ),
              //                   ),
              //                 ),
              //                 InkWell(
              //                   onTap: () {
              //                     //onTapCloseReply
              //                     replyingTo = "";
              //                     replying = false;
              //                     setState(() {});
              //                   },
              //                   child: Icon(
              //                     Icons.close,
              //                     color: Colors.black12,
              //                     size: 24,
              //                   ),
              //                 ),
              //               ],
              //             ))
              //             : Container(),
              //         replying
              //             ? Container(
              //           height: 1,
              //           color: Colors.grey.shade300,
              //         )
              //             : Container(),
              //         Container(
              //           width: width * 0.95,
              //           height: 60,
              //           color: const Color(0xffF4F4F5),
              //           padding: const EdgeInsets.symmetric(
              //             vertical: 8,
              //             horizontal: 16,
              //           ),
              //           child: Row(
              //             children: <Widget>[
              //               Expanded(
              //                 child: Container(
              //                   child: GestureDetector(
              //                     onTap: () {
              //                       // Action à effectuer lorsque le champ de saisie est tapé
              //                       printVm('TextField tapped');
              //                     },
              //                     child: TextFormField(
              //                       focusNode: _focusNode,
              //
              //
              //                       onTap: () async {
              //                         // _controller.animateTo(
              //                         //   _controller.position.maxScrollExtent *
              //                         //       34,
              //                         //   duration: Duration(milliseconds: 800),
              //                         //   curve: Curves.fastOutSlowIn,
              //                         // );
              //                         printVm("tap");
              //                       },
              //                       controller: _textController,
              //                       keyboardType: TextInputType.multiline,
              //                       textCapitalization:
              //                       TextCapitalization.sentences,
              //                       minLines: 1,
              //                       maxLines: 3,
              //                       onChanged: (value) {
              //                         //onTextChanged
              //                       },
              //                       style: const TextStyle(color: Colors.black),
              //                       decoration: InputDecoration(
              //                         hintText: "commentez...",
              //                         hintMaxLines: 1,
              //                         contentPadding:
              //                         const EdgeInsets.symmetric(
              //                             horizontal: 8.0, vertical: 10),
              //                         hintStyle: const TextStyle(fontSize: 16),
              //                         fillColor: Colors.white,
              //                         filled: true,
              //                         enabledBorder: OutlineInputBorder(
              //                           borderRadius:
              //                           BorderRadius.circular(30.0),
              //                           borderSide: const BorderSide(
              //                             color: Colors.white,
              //                             width: 0.2,
              //                           ),
              //                         ),
              //                         focusedBorder: OutlineInputBorder(
              //                           borderRadius:
              //                           BorderRadius.circular(30.0),
              //                           borderSide: const BorderSide(
              //                             color: Colors.black26,
              //                             width: 0.2,
              //                           ),
              //                         ),
              //                       ),
              //                     ),
              //                   ),
              //                 ),
              //               ),
              //               Padding(
              //                 padding: const EdgeInsets.only(left: 16),
              //                 child: GestureDetector(
              //                   child: Icon(
              //                     Icons.send,
              //                     color: Colors.green,
              //                     size: 24,
              //                   ),
              //                   onTap: sendMessageTap
              //                       ? () {}
              //                       : () async {
              //                     printVm("send tap;");
              //                     setState(() {
              //                       sendMessageTap = true;
              //
              //                     });
              //                     String textComment=_textController.text;
              //
              //                     if (_textController.text.isNotEmpty) {
              //                       _textController.text="";
              //                       if (replying) {
              //
              //                         printVm("****** reply ++++response sended user id **** : ${replyUser_id}");
              //
              //                         ResponsePostComment comment =
              //                         ResponsePostComment(user_id: authProvider.loginUserData!.id);
              //                         comment.user_id =
              //                             authProvider.loginUserData!.id;
              //                         comment.user_logo_url =
              //                             authProvider.loginUserData!.imageUrl;
              //                         comment.user_pseudo =
              //                             authProvider.loginUserData!.pseudo;
              //                         comment.post_comment_id =
              //                             commentSelectedToReply.id;
              //                         comment.message =
              //                             textComment;
              //                         comment.createdAt = DateTime.now()
              //                             .microsecondsSinceEpoch;
              //                         comment.updatedAt = DateTime.now()
              //                             .microsecondsSinceEpoch;
              //                         commentSelectedToReply
              //                             .responseComments!
              //                             .add(comment);
              //                         postPro
              //                             .updateComment(
              //                             commentSelectedToReply)
              //                             .then(
              //                               (value) async {
              //                             if (value) {
              //                               // _textController.text = "";
              //                               printVm("****** response sended user id **** : ${replyUser_id}");
              //
              //                               await authProvider.getUserById(replyUser_id).then(
              //                                     (users) async {
              //                                   if(users.isNotEmpty){
              //
              //                                     UserData receiver = users.first;
              //                                     printVm("****** response sended user **** : ${receiver.toJson()}");
              //                                     NotificationData notif=NotificationData();
              //                                     notif.id=firestore
              //                                         .collection('Notifications')
              //                                         .doc()
              //                                         .id;
              //                                     notif.titre="Commentaire 💬";
              //                                     notif.media_url=authProvider.loginUserData.imageUrl;
              //                                     notif.type=NotificationType.POST.name;
              //                                     notif.description="@${authProvider.loginUserData.pseudo!} a repondu à votre commentaire 💬";
              //                                     notif.users_id_view=[];
              //                                     notif.user_id=authProvider.loginUserData.id;
              //                                     notif.receiver_id=receiver!.id!;
              //                                     notif.post_id=widget.post!.id!;
              //                                     notif.post_data_type=PostDataType.COMMENT.name!;
              //
              //                                     notif.updatedAt =
              //                                         DateTime.now().microsecondsSinceEpoch;
              //                                     notif.createdAt =
              //                                         DateTime.now().microsecondsSinceEpoch;
              //                                     notif.status = PostStatus.VALIDE.name;
              //
              //                                     // users.add(pseudo.toJson());
              //
              //                                     await firestore.collection('Notifications').doc(notif.id).set(notif.toJson());
              //
              //                                     await authProvider.sendNotification(
              //                                         userIds: [receiver!.oneIgnalUserid!],
              //                                         smallImage: "${authProvider.loginUserData.imageUrl!}",
              //                                         send_user_id: "${authProvider.loginUserData.id!}",
              //                                         recever_user_id: "${receiver!.id!}",
              //                                         message: "📢 @${authProvider.loginUserData.pseudo!} a repondu à votre commentaire 💬",
              //                                         type_notif: NotificationType.POST.name,
              //                                         post_id: "${widget.post!.id!}",
              //                                         post_type: PostDataType.COMMENT.name, chat_id: ''
              //                                     );
              //
              //
              //                                   }
              //                                 },
              //                               );
              //
              //                               sendMessageTap = false;
              //                               _focusNode.unfocus();
              //                               _textController.text = "";
              //
              //                               setState(() {
              //                                 replying = false;
              //                               });
              //                             } else {
              //                               printVm(
              //                                   "erreru sender response");
              //
              //                               sendMessageTap = false;
              //                             }
              //
              //                             sendMessageTap = false;
              //                           },
              //                         );
              //                       } else {
              //                         PostComment comment = PostComment();
              //                         comment.user_id =
              //                             authProvider.loginUserData.id;
              //                         comment.user =
              //                             authProvider.loginUserData;
              //                         comment.post_id = widget.post.id;
              //                         comment.users_like_id = [];
              //                         comment.responseComments = [];
              //                         comment.message =
              //                             textComment;
              //                         comment.loves = 0;
              //                         comment.likes = 0;
              //                         comment.comments = 0;
              //                         comment.createdAt = DateTime.now()
              //                             .microsecondsSinceEpoch;
              //                         comment.updatedAt = DateTime.now()
              //                             .microsecondsSinceEpoch;
              //
              //                         postPro.newComment(comment).then(
              //                               (value) async {
              //                             if (value) {
              //
              //                               widget.post.comments =
              //                                   widget.post.comments! + 1;
              //
              //
              //                               CollectionReference userCollect =
              //                               FirebaseFirestore.instance.collection('Users');
              //                               // Get docs from collection reference
              //                               QuerySnapshot querySnapshotUser = await userCollect.where("id",isEqualTo: widget.post.user!.id!).get();
              //                               // Afficher la liste
              //                               List<UserData>  listUsers = querySnapshotUser.docs.map((doc) =>
              //                                   UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();
              //                               if (listUsers.isNotEmpty) {
              //
              //                                 listUsers.first!.comments=listUsers.first!.comments!+1;
              //                                 postPro.updatePost(widget.post, listUsers.first!!,context);
              //                                 await authProvider.getAppData();
              //                                 authProvider.appDefaultData.nbr_comments=authProvider.appDefaultData.nbr_comments!+1;
              //                                 authProvider.updateAppData(authProvider.appDefaultData);
              //                               }else{
              //                                 widget.post.user!.comments=widget.post.user!.comments!+1;
              //                                 postPro.updatePost(widget.post,widget.post.user!,context);
              //                                 await authProvider.getAppData();
              //
              //                                 authProvider.appDefaultData.nbr_comments=authProvider.appDefaultData.nbr_comments!+1;
              //                                 authProvider.updateAppData(authProvider.appDefaultData);
              //                               }
              //
              //                               await authProvider.sendNotification(
              //                                   userIds: [widget.post.user!.oneIgnalUserid!],
              //                                   smallImage: "${authProvider.loginUserData.imageUrl!}",
              //                                   send_user_id: "${authProvider.loginUserData.id!}",
              //                                   recever_user_id: "",
              //                                   message: "📢 @${authProvider.loginUserData.pseudo!} a commenté 💬 votre look",
              //                                   type_notif: NotificationType.POST.name,
              //                                   post_id: "${widget.post!.id!}",
              //                                   post_type: PostDataType.COMMENT.name, chat_id: ''
              //                               );
              //
              //                               NotificationData notif=NotificationData();
              //                               notif.id=firestore
              //                                   .collection('Notifications')
              //                                   .doc()
              //                                   .id;
              //                               notif.titre="Commentaire 💬";
              //                               notif.media_url=authProvider.loginUserData.imageUrl;
              //                               notif.type=NotificationType.POST.name;
              //                               notif.description="@${authProvider.loginUserData.pseudo!} a commenté 💬 votre look";
              //                               notif.users_id_view=[];
              //                               notif.user_id=authProvider.loginUserData.id;
              //                               notif.receiver_id=widget.post!.user!.id!;
              //                               notif.post_id=widget.post!.id!;
              //                               notif.post_data_type=PostDataType.COMMENT.name!;
              //
              //                               notif.updatedAt =
              //                                   DateTime.now().microsecondsSinceEpoch;
              //                               notif.createdAt =
              //                                   DateTime.now().microsecondsSinceEpoch;
              //                               notif.status = PostStatus.VALIDE.name;
              //
              //                               // users.add(pseudo.toJson());
              //
              //                               await firestore.collection('Notifications').doc(notif.id).set(notif.toJson());
              //
              //
              //                               _textController.text = "";
              //                               printVm("commment envoyer");
              //                               _focusNode.unfocus();
              //                               postPro.listConstpostsComment
              //                                   .add(comment);
              //
              //                               postPro.listConstpostsComment
              //                                   .sort((a, b) => b
              //                                   .createdAt!
              //                                   .compareTo(
              //                                   a.createdAt!));
              //
              //                               sendMessageTap = false;
              //                               _focusNode.unfocus();
              //
              //                             } else {
              //                               printVm("erreru commment");
              //
              //                               sendMessageTap = false;
              //                             }
              //
              //                             sendMessageTap = false;
              //                           },
              //                         );
              //                       }
              //                     }
              //                     setState(() {
              //                       sendMessageTap = false;
              //
              //                     });
              //                   },
              //                 ),
              //               ),
              //             ],
              //           ),
              //         ),
              //       ],
              //     ),
              //   ),
              // )
            ]),
          );
        }),
      ),

      bottomNavigationBar: FlutterTagger(
        controller: _controller,
        animationController: _animationController,
        onSearch: (query, triggerChar) {
          // if (triggerChar == "@") {
          //   searchViewModel.searchUser(query);
          // }
          if (triggerChar == "#") {
            searchViewModel.searchHashtag(query);
          }
        },
        triggerCharacterAndStyles: const {
          // "@": TextStyle(color: Colors.pinkAccent),
          "#": TextStyle(color: Colors.green),
        },
        tagTextFormatter: (id, tag, triggerCharacter) {
          return "$triggerCharacter$id#$tag#";
        },
        overlayHeight: overlayHeight,
        overlay: SearchResultOverlay(
          animation: _animation,
          tagController: _controller,
        ),
        builder: (context, containerKey) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (replying && replyingTo != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const Icon(Icons.reply, color: Colors.blueAccent),
                      const SizedBox(width: 8),
                      Text(
                        "Réponse à @${replyingTo!}",
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.redAccent),
                        onPressed: () {
                          setState(() {
                            replying = false;
                            replyingTo = "";
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              CommentTextField(
                focusNode: _focusNode,
                containerKey: containerKey,
                insets: insets,
                controller: _controller,
                onSend: () async {
                  printVm("***************send comment;");
                  setState(() {
                    sendMessageTap = true;

                  });

                  String textComment=_controller.text;
                  _controller.clear();
                  FocusScope.of(context).unfocus();

                  if (textComment.isNotEmpty) {
                    // _controller.text="";
                    if (replying) {

                      printVm("****** reply ++++response sended user id **** : ${replyUser_id}");

                      ResponsePostComment comment =
                      ResponsePostComment(user_id: authProvider.loginUserData!.id);
                      comment.user_id =
                          authProvider.loginUserData!.id;
                      comment.user_logo_url =
                          authProvider.loginUserData!.imageUrl;
                      comment.user_pseudo =
                          authProvider.loginUserData!.pseudo;
                      comment.post_comment_id =
                          commentSelectedToReply.id;
                      comment.message =
                          textComment;
                      comment.createdAt = DateTime.now()
                          .microsecondsSinceEpoch;
                      comment.updatedAt = DateTime.now()
                          .microsecondsSinceEpoch;
                      commentSelectedToReply
                          .responseComments!
                          .add(comment);
                      postProviders
                          .updateComment(
                          commentSelectedToReply)
                          .then(
                            (value) async {
                          if (value) {
                            // _textController.text = "";
                            printVm("****** response sended user id **** : ${replyUser_id}");

                            await authProvider.getUserById(replyUser_id).then(
                                  (users) async {
                                if(users.isNotEmpty){

                                  UserData receiver = users.first;
                                  printVm("****** response sended user **** : ${receiver.toJson()}");
                                  NotificationData notif=NotificationData();
                                  notif.id=firestore
                                      .collection('Notifications')
                                      .doc()
                                      .id;
                                  notif.titre="Commentaire 💬";
                                  notif.media_url=authProvider.loginUserData.imageUrl;
                                  notif.type=NotificationType.POST.name;
                                  notif.description="@${authProvider.loginUserData.pseudo!} a repondu à votre commentaire 💬";
                                  notif.users_id_view=[];
                                  notif.user_id=authProvider.loginUserData.id;
                                  notif.receiver_id=receiver!.id!;
                                  notif.post_id=widget.post!.id!;
                                  notif.post_data_type=PostDataType.COMMENT.name!;

                                  notif.updatedAt =
                                      DateTime.now().microsecondsSinceEpoch;
                                  notif.createdAt =
                                      DateTime.now().microsecondsSinceEpoch;
                                  notif.status = PostStatus.VALIDE.name;

                                  // users.add(pseudo.toJson());

                                  await firestore.collection('Notifications').doc(notif.id).set(notif.toJson());

                                  await authProvider.sendNotification(
                                      userIds: [receiver!.oneIgnalUserid!],
                                      smallImage: "${authProvider.loginUserData.imageUrl!}",
                                      send_user_id: "${authProvider.loginUserData.id!}",
                                      recever_user_id: "${receiver!.id!}",
                                      message: "📢 @${authProvider.loginUserData.pseudo!} a repondu à votre commentaire 💬",
                                      type_notif: NotificationType.POST.name,
                                      post_id: "${widget.post!.id!}",
                                      post_type: PostDataType.COMMENT.name, chat_id: ''
                                  );


                                }
                              },
                            );

                            sendMessageTap = false;
                            // _focusNode.unfocus();
                            _textController.text = "";

                            setState(() {
                              replying = false;
                            });
                          } else {
                            printVm(
                                "erreru sender response");

                            sendMessageTap = false;
                          }

                          sendMessageTap = false;
                        },
                      );
                    } else {
                      PostComment comment = PostComment();
                      comment.user_id =
                          authProvider.loginUserData.id;
                      comment.user =
                          authProvider.loginUserData;
                      comment.post_id = widget.post.id;
                      comment.users_like_id = [];
                      comment.responseComments = [];
                      comment.message =
                          textComment;
                      comment.loves = 0;
                      comment.likes = 0;
                      comment.comments = 0;
                      comment.createdAt = DateTime.now()
                          .microsecondsSinceEpoch;
                      comment.updatedAt = DateTime.now()
                          .microsecondsSinceEpoch;

                   await   postProviders.newComment(comment).then(
                            (value) async {
                          if (value) {

                            widget.post.comments =
                                widget.post.comments! + 1;


                            CollectionReference userCollect =
                            FirebaseFirestore.instance.collection('Users');
                            // Get docs from collection reference
                            QuerySnapshot querySnapshotUser = await userCollect.where("id",isEqualTo: widget.post.user!.id!).get();
                            // Afficher la liste
                            List<UserData>  listUsers = querySnapshotUser.docs.map((doc) =>
                                UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();
                            if (listUsers.isNotEmpty) {

                              listUsers.first!.comments=listUsers.first!.comments!+1;
                              postProviders.updatePost(widget.post, listUsers.first!!,context);
                              await authProvider.getAppData();
                              authProvider.appDefaultData.nbr_comments=authProvider.appDefaultData.nbr_comments!+1;
                              authProvider.updateAppData(authProvider.appDefaultData);
                            }else{
                              widget.post.user!.comments=widget.post.user!.comments!+1;
                              postProviders.updatePost(widget.post,widget.post.user!,context);
                              await authProvider.getAppData();

                              authProvider.appDefaultData.nbr_comments=authProvider.appDefaultData.nbr_comments!+1;
                              authProvider.updateAppData(authProvider.appDefaultData);
                            }

                            await authProvider.sendNotification(
                                userIds: [widget.post.user!.oneIgnalUserid!],
                                smallImage: "${authProvider.loginUserData.imageUrl!}",
                                send_user_id: "${authProvider.loginUserData.id!}",
                                recever_user_id: "",
                                message: "📢 @${authProvider.loginUserData.pseudo!} a commenté 💬 votre look",
                                type_notif: NotificationType.POST.name,
                                post_id: "${widget.post!.id!}",
                                post_type: PostDataType.COMMENT.name, chat_id: ''
                            );

                            NotificationData notif=NotificationData();
                            notif.id=firestore
                                .collection('Notifications')
                                .doc()
                                .id;
                            notif.titre="Commentaire 💬";
                            notif.media_url=authProvider.loginUserData.imageUrl;
                            notif.type=NotificationType.POST.name;
                            notif.description="@${authProvider.loginUserData.pseudo!} a commenté 💬 votre look";
                            notif.users_id_view=[];
                            notif.user_id=authProvider.loginUserData.id;
                            notif.receiver_id=widget.post!.user!.id!;
                            notif.post_id=widget.post!.id!;
                            notif.post_data_type=PostDataType.COMMENT.name!;

                            notif.updatedAt =
                                DateTime.now().microsecondsSinceEpoch;
                            notif.createdAt =
                                DateTime.now().microsecondsSinceEpoch;
                            notif.status = PostStatus.VALIDE.name;

                            // users.add(pseudo.toJson());

                            await firestore.collection('Notifications').doc(notif.id).set(notif.toJson());


                            _textController.text = "";
                            printVm("commment envoyer");
                            _focusNode.unfocus();
                            postProviders.listConstpostsComment
                                .add(comment);

                            postProviders.listConstpostsComment
                                .sort((a, b) => b
                                .createdAt!
                                .compareTo(
                                a.createdAt!));

                            sendMessageTap = false;
                            _focusNode.unfocus();

                          } else {
                            printVm("erreru commment");

                            sendMessageTap = false;
                          }

                          sendMessageTap = false;
                        },
                      );
                    }
                  }
                  setState(() {
                    sendMessageTap = false;

                  });

                  // _controller.clear();
                },
              ),
            ],
          );
        },
      ),

    );
  }
}
