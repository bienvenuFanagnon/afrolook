import 'dart:async';
import 'dart:math';

import 'package:afrotok/pages/home/postMenu.dart';
import 'package:afrotok/pages/story/afroStory/repository.dart';
import 'package:afrotok/pages/userPosts/hashtag/textHashTag/views/view_models/home_view_model.dart';
import 'package:afrotok/pages/userPosts/hashtag/textHashTag/views/view_models/search_view_model.dart';
import 'package:afrotok/pages/userPosts/hashtag/textHashTag/views/widgets/comment_text_field.dart';
import 'package:afrotok/pages/userPosts/hashtag/textHashTag/views/widgets/search_result_overlay.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:comment_tree/widgets/comment_tree_widget.dart';
import 'package:comment_tree/widgets/tree_theme_data.dart';
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
import 'package:hashtagable_v3/widgets/hashtag_text.dart';
import 'package:intl/intl.dart';

import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:flutter_story_presenter/flutter_story_presenter.dart';

import '../../../../constant/textCustom.dart';
import '../../../../providers/authProvider.dart';
import '../../../component/consoleWidget.dart';
import '../../../component/showImage.dart';
import '../../../component/showUserDetails.dart';


class StoryComments extends StatefulWidget {
  final StoryItem story;
  final UserData userStory;
  const StoryComments({super.key, required this.story, required this.userStory});

  @override
  State<StoryComments> createState() => _StoryCommentsState();
}

class _StoryCommentsState extends State<StoryComments> with TickerProviderStateMixin{
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
  String? extractName(String text) {
    final regex = RegExp(r'@([A-Za-z0-9 ]+)');
    final match = regex.firstMatch(text);
    return match?.group(1);
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
                  visible: widget.userStory.id != authProvider.loginUserData.id,
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
                  visible: widget.userStory.id == authProvider.loginUserData.id,
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
                        if (widget.userStory.id == authProvider.loginUserData.id) {
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
    return SingleChildScrollView(
      child: Column(
        children: pcms.map((pcm) {
          return CommentTreeWidget<PostComment, ResponsePostComment>(
            pcm,
            pcm.responseComments!,
            treeThemeData: TreeThemeData(
              lineColor: Colors.green, // Ligne entre parent et enfant
              lineWidth: 2,
            ),
            avatarRoot: (context, data) => PreferredSize(
              preferredSize: Size.fromRadius(18),
              child: GestureDetector(
                onTap: () async {
                  await  authProvider.getUserById(data.user!.id!).then((users) async {
                    if(users.isNotEmpty){
                      showUserDetailsModalDialog(users.first, width, height,context);

                    }
                  },);
                },
                child: CircleAvatar(
                  radius: 15,
                  backgroundImage: NetworkImage(data.user!.imageUrl ?? ''),
                  onBackgroundImageError: (_, __) => AssetImage('assets/images/404.png'),
                ),
              ),
            ),
            contentRoot: (context, data) => _buildCommentContent(data, width, height),
            avatarChild: (context, data) => PreferredSize(
              preferredSize: Size.fromRadius(18),
              child: GestureDetector(
                onTap: () async {
                  await  authProvider.getUserById(data.user_id!).then((users) async {
                    if(users.isNotEmpty){
                      showUserDetailsModalDialog(users.first, width, height,context);

                    }
                  },);
                },
                child: CircleAvatar(
                  radius: 13,
                  backgroundImage: NetworkImage(data.user_logo_url ?? ''),
                ),
              ),
            ),
            contentChild: (context, data) => _buildReplyContent(pcm,data, width, height),
          );
        }).toList(),
      ),
    );
  }

  /// **Widget pour afficher un commentaire principal**
  Widget _buildCommentContent(PostComment pcm, double width, double height) {
    return Padding(
      padding: const EdgeInsets.all(2.0),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("@${pcm.user!.pseudo!}", style: TextStyle(fontWeight: FontWeight.bold)),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: width*0.5, // Définir la largeur maximale souhaitée
                  ),
                  child: HashTagText(

                    text: "${pcm.status==PostStatus.SUPPRIMER.name?"Supprimé":pcm.message}",
                    decoratedStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,

                      color: Colors.green,
                      fontFamily: 'Nunito', // Définir la police Nunito
                    ),
                    basicStyle: TextStyle(
                      fontSize: SizeText.homeProfileTextSize,
                      color: pcm.status==PostStatus.SUPPRIMER.name?Colors.red:ConstColors.textColors,
                      fontWeight: FontWeight.normal,
                      fontFamily: 'Nunito', // Définir la police Nunito
                    ),
                    textAlign: TextAlign.left, // Centrage du texte
                    maxLines: null, // Permet d'afficher le texte sur plusieurs lignes si nécessaire
                    softWrap: true, // Assure que le texte se découpe sur plusieurs lignes si nécessaire
                    // overflow: TextOverflow.ellipsis, // Ajoute une ellipse si le texte dépasse
                    onTap: (text) {
                      _handleTagClick(text,width,height);
                    },
                    decorateAtSign: true,

                  ),
                ),
              ),
              // HashTagText(
              //   text: pcm.status == PostStatus.SUPPRIMER.name ? "Supprimé" : pcm.message!,
              //   decoratedStyle: TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
              //   basicStyle: TextStyle(color: Colors.black),
              //   onTap: (text) => _handleTagClick(text),
              // ),
              Text(
                "${formaterDateTime(DateTime.fromMicrosecondsSinceEpoch(pcm.createdAt!))}",
                style: TextStyle(fontSize: 1, color: Colors.grey),
              ),
            ],
          ),
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
      ),
    );
  }

  /// **Widget pour afficher une réponse à un commentaire**
  Widget _buildReplyContent(PostComment pcm,ResponsePostComment rpc, double width, double height) {
    return Padding(
      padding: const EdgeInsets.only(top: 5.0),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("@${rpc.user_pseudo}", style: TextStyle(fontWeight: FontWeight.bold)),
              // HashTagText(
              //   text: rpc.status == PostStatus.SUPPRIMER.name ? "Supprimé" : rpc.message!,
              //   decoratedStyle: TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
              //   basicStyle: TextStyle(color: Colors.black),
              //   onTap: (text) => _handleTagClick(text),
              // ),
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: width*0.45, // Définir la largeur maximale souhaitée
                  ),
                  child: HashTagText(

                    text: "${rpc.status==PostStatus.SUPPRIMER.name?"Supprimé":rpc.message}",
                    decoratedStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,

                      color: Colors.green,
                      fontFamily: 'Nunito', // Définir la police Nunito
                    ),
                    basicStyle: TextStyle(
                      fontSize: SizeText.homeProfileTextSize,
                      color: rpc.status==PostStatus.SUPPRIMER.name?Colors.red:ConstColors.textColors,
                      fontWeight: FontWeight.normal,
                      fontFamily: 'Nunito', // Définir la police Nunito
                    ),
                    textAlign: TextAlign.left, // Centrage du texte
                    maxLines: null, // Permet d'afficher le texte sur plusieurs lignes si nécessaire
                    softWrap: true, // Assure que le texte se découpe sur plusieurs lignes si nécessaire
                    // overflow: TextOverflow.ellipsis, // Ajoute une ellipse si le texte dépasse
                    onTap: (text) {
                      _handleTagClick(text,width,height);
                    },
                    decorateAtSign: true,

                  ),
                ),
              ),
              Text(
                "${formaterDateTime(DateTime.fromMicrosecondsSinceEpoch(rpc.createdAt!))}",
                style: TextStyle(fontSize: 8, color: Colors.grey),
              ),
            ],
          ),
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
      ),
    );
  }

  /// **Fonction pour gérer les interactions avec les hashtags et mentions**
  Future<void> _handleTagClick(String text,double width, height) async {
    print("Tag cliqué: ${text.replaceFirst('@', '')}");
    if(users.isNotEmpty){
      var user= users.firstWhere((element) => element.pseudo==text.replaceFirst('@', ''),);
      if(user!=null){
        await  authProvider.getUserById(user.id!).then((users) async {
          if(users.isNotEmpty){
            showUserDetailsModalDialog(users.first, width, height,context);

          }
        },);
      }
    }

    // Recherchez l'utilisateur associé et affichez les détails si nécessaire
  }

  List<UserData> users=[];
  @override
  void initState() {
    userProvider.getAllUsers().then((users2) {
      users=users2;
    },);
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
                                              '${widget.userStory.imageUrl!}'),
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
                                                  "@${widget.userStory.pseudo!}",
                                                  fontSize: SizeText
                                                      .homeProfileTextSize,
                                                  couleur:
                                                  ConstColors.textColors,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              TextCustomerUserTitle(
                                                titre:
                                                "${widget.userStory.abonnes!} abonné(s)",
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
                                        // _showPostMenuModalDialog(widget.post);
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
                              // Align(
                              //   alignment: Alignment.topLeft,
                              //   child: SizedBox(
                              //     width: width * 0.9,
                              //     height: 80,
                              //     child: Container(
                              //       alignment: Alignment.centerLeft,
                              //       child: TextCustomerPostDescription(
                              //         titre: "${widget.post.}",
                              //         fontSize: SizeText.homeProfileTextSize,
                              //         couleur: ConstColors.textColors,
                              //         fontWeight: FontWeight.normal,
                              //       ),
                              //     ),
                              //   ),
                              // ),
                              // SizedBox(
                              //   height: 5,
                              // ),
                              // Align(
                              //   alignment: Alignment.topLeft,
                              //   child: TextCustomerPostDescription(
                              //     titre:
                              //     "${formaterDateTime(DateTime.fromMicrosecondsSinceEpoch(widget.post.createdAt!))}",
                              //     fontSize: SizeText.homeProfileDateTextSize,
                              //     couleur: ConstColors.textColors,
                              //     fontWeight: FontWeight.bold,
                              //   ),
                              // ),
                              // SizedBox(
                              //   height: 5,
                              // ),
                              // widget.post!.images!.isEmpty
                              //     ? Container()
                              //     : Padding(
                              //   padding: const EdgeInsets.all(8.0),
                              //   child: GestureDetector(
                              //     onTap: () {
                              //       showImageDetailsModalDialog(widget.post!.images!.first!, width, height,context);
                              //
                              //     },
                              //     child: Container(
                              //       width: 100,
                              //       height: 50,
                              //       child: ClipRRect(
                              //         borderRadius:
                              //         BorderRadius.all(
                              //             Radius.circular(10)),
                              //         child: Container(
                              //           child: CachedNetworkImage(
                              //             fit: BoxFit.cover,
                              //             imageUrl:
                              //             '${widget.post!.images!.first}',
                              //             progressIndicatorBuilder: (context,
                              //                 url,
                              //                 downloadProgress) =>
                              //             //  LinearProgressIndicator(),
                              //
                              //             Skeletonizer(
                              //                 child: SizedBox(
                              //                     width: 400,
                              //                     height: 450,
                              //                     child: ClipRRect(
                              //                         borderRadius:
                              //                         BorderRadius.all(Radius.circular(
                              //                             10)),
                              //                         child: Image
                              //                             .asset(
                              //                             'assets/images/404.png')))),
                              //             errorWidget: (context,
                              //                 url, error) =>
                              //                 Skeletonizer(
                              //                     child: Container(
                              //                         width: 400,
                              //                         height: 450,
                              //                         child: Image
                              //                             .asset(
                              //                           "assets/images/404.png",
                              //                           fit: BoxFit
                              //                               .cover,
                              //                         ))),
                              //           ),
                              //         ),
                              //       ),
                              //     ),
                              //   ),
                              // ),
                              // SizedBox(
                              //   height: 10,
                              // ),
                              FutureBuilder<List<PostComment>>(
                                  future: postProviders
                                      .getStoryCommentsNoStream(
                                      widget.story),
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
                                  })
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ]),
          );
        }),
      ),

      bottomNavigationBar: FlutterTagger(
        controller: _controller,
        animationController: _animationController,
        onSearch: (query, triggerChar) {
          if (triggerChar == "@") {
            searchViewModel.searchUser(query,users);
          }
          if (triggerChar == "#") {
            searchViewModel.searchHashtag(query);
          }
        },
        triggerCharacterAndStyles: const {
          "@": TextStyle(color: Colors.pinkAccent),
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
                        "Réponse à ${replyingTo!}",
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
                  List<UserData> userNames=[];
                  List<String> userOneSignalIds=[];

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
                            widget.story.comment =
                            widget.story.comment==null?0: widget.story.comment! + 1;
                          for(var story in  widget.userStory.stories!){
                            if(story.createdAt==widget.story.createdAt){
                             int index= widget.userStory.stories!.indexOf(story);
                             story.nbrComment= widget.story.comment;
                             widget.userStory.stories![index]=story;
                             authProvider.updateUser(widget.userStory);

                            }

                          }


                            CollectionReference userCollect =
                            FirebaseFirestore.instance.collection('Users');
                            // Get docs from collection reference
                            QuerySnapshot querySnapshotUser = await userCollect.where("id",isEqualTo: widget.userStory.id!).get();
                            // Afficher la liste
                            List<UserData>  listUsers = querySnapshotUser.docs.map((doc) =>
                                UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();
                            // if (listUsers.isNotEmpty) {
                            //
                            //   listUsers.first!.comments=listUsers.first!.comments!+1;
                            //   postProviders.updatePost(widget.story, listUsers.first!!,context);
                            //   await authProvider.getAppData();
                            //   authProvider.appDefaultData.nbr_comments=authProvider.appDefaultData.nbr_comments!+1;
                            //   authProvider.updateAppData(authProvider.appDefaultData);
                            // }else{
                            //   widget.userStory.comments=widget.userStory.comments!+1;
                            //   postProviders.updatePost(widget.story,widget.userStory,context);
                            //   await authProvider.getAppData();
                            //
                            //   authProvider.appDefaultData.nbr_comments=authProvider.appDefaultData.nbr_comments!+1;
                            //   authProvider.updateAppData(authProvider.appDefaultData);
                            // }
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
                                  notif.titre="Commentaire chronique💬";
                                  notif.media_url=authProvider.loginUserData.imageUrl;
                                  notif.type=NotificationType.POST.name;
                                  notif.description="@${authProvider.loginUserData.pseudo!} a repondu à votre commentaire chronique💬";
                                  notif.users_id_view=[];
                                  notif.user_id=authProvider.loginUserData.id;
                                  notif.receiver_id=receiver!.id!;
                                  notif.post_id=widget.story!.createdAt!.toString();
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
                                      message: "📢 @${authProvider.loginUserData.pseudo!} a repondu à votre commentaire chronique💬",
                                      type_notif: NotificationType.POST.name,
                                      post_id: "${widget.story!.createdAt!}",
                                      post_type: PostDataType.COMMENT.name, chat_id: ''
                                  );
                                  // Expression régulière pour trouver les noms commençant par @
                                  RegExp regExp = RegExp(r'@\w+');

                                  // Trouver toutes les correspondances
                                  Iterable<Match> matches = regExp.allMatches(textComment);

                                  // Extraire les noms trouvés
                                  List<String> usernames = matches.map((match) => match.group(0)!).toList();


                                  // Afficher les noms trouvés
                                  if(usernames.isNotEmpty){
                                    usernames.forEach((username) {
                                      print("username @ : ${username}");
                                      var user= users.firstWhere((element) => element.pseudo!.contains(username.replaceFirst('@', ''),));
                                     if(user!=null){
                                       userNames.add(user);
                                       userOneSignalIds.add(user.oneIgnalUserid!);
                                     }

                                    });

                                    await authProvider.sendNotification(
                                        userIds: userOneSignalIds,
                                        smallImage: "${authProvider.loginUserData.imageUrl!}",
                                        send_user_id: "${authProvider.loginUserData.id!}",
                                        recever_user_id: "",
                                        message: "📢 @${authProvider.loginUserData.pseudo!} a parlé de vous dans un chronique ! !💬",
                                        type_notif: NotificationType.POST.name,
                                        post_id: "${widget.story!.createdAt!}",
                                        post_type: PostDataType.COMMENT.name, chat_id: ''
                                    );
                                    if(userNames.isNotEmpty){
                                      // for(var user in userNames){
                                      //   NotificationData notif2=NotificationData();
                                      //   notif.id=firestore
                                      //       .collection('Notifications')
                                      //       .doc()
                                      //       .id;
                                      //   notif.titre="Tagué 💬";
                                      //   notif.media_url=authProvider.loginUserData.imageUrl;
                                      //   notif.type=NotificationType.POST.name;
                                      //   notif.description="@${authProvider.loginUserData.pseudo!} a parlé de vous dans un chronique !💬";
                                      //   notif.users_id_view=[];
                                      //   notif.user_id=authProvider.loginUserData.id;
                                      //   notif.receiver_id=user!.id!;
                                      //   notif.post_id=widget.story!.createdAt!.toString();
                                      //   notif.post_data_type=PostDataType.COMMENT.name!;
                                      //
                                      //   notif.updatedAt =
                                      //       DateTime.now().microsecondsSinceEpoch;
                                      //   notif.createdAt =
                                      //       DateTime.now().microsecondsSinceEpoch;
                                      //   notif.status = PostStatus.VALIDE.name;
                                      //
                                      //   // users.add(pseudo.toJson());
                                      //
                                      //   await firestore.collection('Notifications').doc(notif2.id).set(notif2.toJson());
                                      //
                                      //
                                      // }


                                    }
                                  }



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
                      comment.post_id = widget.story.createdAt.toString();
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

                            widget.story.comment =
                                widget.story.comment! + 1;

                            for(var story in  widget.userStory.stories!){
                              if(story.createdAt==widget.story.createdAt){
                                int index= widget.userStory.stories!.indexOf(story);
                                story.nbrComment= widget.story.comment;
                                widget.userStory.stories![index]=story;
                                authProvider.updateUser(widget.userStory);

                              }

                            }

                            CollectionReference userCollect =
                            FirebaseFirestore.instance.collection('Users');
                            // Get docs from collection reference
                            QuerySnapshot querySnapshotUser = await userCollect.where("id",isEqualTo: widget.userStory.id!).get();
                            // Afficher la liste
                            List<UserData>  listUsers = querySnapshotUser.docs.map((doc) =>
                                UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();
                            // if (listUsers.isNotEmpty) {
                            //
                            //   listUsers.first!.comments=listUsers.first!.comments!+1;
                            //   postProviders.updatePost(widget.story, listUsers.first!!,context);
                            //   await authProvider.getAppData();
                            //   authProvider.appDefaultData.nbr_comments=authProvider.appDefaultData.nbr_comments!+1;
                            //   authProvider.updateAppData(authProvider.appDefaultData);
                            // }else{
                            //   widget.userStory.comments=widget.userStory.comments!+1;
                            //   postProviders.updatePost(widget.story,widget.userStory,context);
                            //   await authProvider.getAppData();
                            //
                            //   authProvider.appDefaultData.nbr_comments=authProvider.appDefaultData.nbr_comments!+1;
                            //   authProvider.updateAppData(authProvider.appDefaultData);
                            // }

                            await authProvider.sendNotification(
                                userIds: [widget.userStory.oneIgnalUserid!],
                                smallImage: "${authProvider.loginUserData.imageUrl!}",
                                send_user_id: "${authProvider.loginUserData.id!}",
                                recever_user_id: "",
                                message: "📢 @${authProvider.loginUserData.pseudo!} a commenté 💬 votre chronique",
                                type_notif: NotificationType.POST.name,
                                post_id: "${widget.story!.createdAt!}",
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
                            notif.receiver_id=widget!.userStory!.id!;
                            notif.post_id=widget.story!.createdAt!.toString();
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

                            // Expression régulière pour trouver les noms commençant par @
                            RegExp regExp = RegExp(r'@\w+');

                            // Trouver toutes les correspondances
                            Iterable<Match> matches = regExp.allMatches(textComment);

                            // Extraire les noms trouvés
                            List<String> usernames = matches.map((match) => match.group(0)!).toList();
                            String? extractedName = extractName(textComment);
                            // bool nameExists = extractedName != null && users.contains(extractedName);
                            if(usernames.isNotEmpty){
                              usernames.forEach((username) {
                                print("username @ : ${username}");
                                var user= users.firstWhere((element) => element.pseudo!.contains(username.replaceFirst('@', ''),));
                                if(user!=null){
                                  userNames.add(user);
                                  userOneSignalIds.add(user.oneIgnalUserid!);
                                }
                              });

                              await authProvider.sendNotification(
                                  userIds: userOneSignalIds,
                                  smallImage: "${authProvider.loginUserData.imageUrl!}",
                                  send_user_id: "${authProvider.loginUserData.id!}",
                                  recever_user_id: "",
                                  message: "📢 @${authProvider.loginUserData.pseudo!} a parlé de vous dans un chronique !💬",
                                  type_notif: NotificationType.POST.name,
                                  post_id: "${widget.story!.createdAt!}",
                                  post_type: PostDataType.COMMENT.name, chat_id: ''
                              );
                              if(userNames.isNotEmpty){
                                // for(var user in userNames){
                                //   NotificationData notif2=NotificationData();
                                //   notif.id=firestore
                                //       .collection('Notifications')
                                //       .doc()
                                //       .id;
                                //   notif.titre="Tagué 💬";
                                //   notif.media_url=authProvider.loginUserData.imageUrl;
                                //   notif.type=NotificationType.POST.name;
                                //   notif.description="@${authProvider.loginUserData.pseudo!} a parlé de vous dans un chronique !💬";
                                //   notif.users_id_view=[];
                                //   notif.user_id=authProvider.loginUserData.id;
                                //   notif.receiver_id=user!.id!;
                                //   notif.post_id=widget.story!.createdAt!.toString();
                                //   notif.post_data_type=PostDataType.COMMENT.name!;
                                //
                                //   notif.updatedAt =
                                //       DateTime.now().microsecondsSinceEpoch;
                                //   notif.createdAt =
                                //       DateTime.now().microsecondsSinceEpoch;
                                //   notif.status = PostStatus.VALIDE.name;
                                //
                                //   // users.add(pseudo.toJson());
                                //
                                //   await firestore.collection('Notifications').doc(notif2.id).set(notif2.toJson());
                                //
                                //
                                // }


                              }
                            }





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
