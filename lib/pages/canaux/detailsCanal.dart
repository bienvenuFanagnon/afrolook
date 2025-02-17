import 'dart:async';
import 'dart:math';
import 'package:afrotok/pages/canaux/canalPostNew.dart';
import 'package:afrotok/pages/canaux/editCanal.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:auto_animated/auto_animated.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/userProvider.dart';
import 'package:afrotok/models/model_data.dart';
import '../component/showImage.dart';
import '../home/slive/utils.dart';
import '../userPosts/postWidgets/postWidgetPage.dart';
import 'followers.dart';

class CanalDetails extends StatefulWidget {
  final Canal canal;

  CanalDetails({required this.canal});

  @override
  _CanalDetailsState createState() => _CanalDetailsState();
}

class _CanalDetailsState extends State<CanalDetails> {
  late UserAuthProvider authProvider = Provider.of<UserAuthProvider>(context, listen: false);
  late UserProvider userProvider = Provider.of<UserProvider>(context, listen: false);
  late PostProvider postProvider = Provider.of<PostProvider>(context, listen: false);
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  StreamController<List<Post>> _streamController = StreamController<List<Post>>();
  Color _color =Colors.green;
  final ScrollController _scrollController = ScrollController();

  DocumentSnapshot? lastDocument;
  bool isLoading = false;
  void _changeColor() {
    final List<Color> colors = [
      Colors.green,
      Colors.green,
      Colors.brown,
      Colors.greenAccent,
      Colors.red,
      Colors.yellow,
    ];
    final random = Random();
    _color = colors[random.nextInt(colors.length)];
  }
  bool isFollowing = false;

  @override
  void initState() {
    super.initState();
    checkIfFollowing();
    postProvider.getCanalPosts(100,widget.canal).listen((data) {
      if (!_streamController.isClosed) {
        _streamController.add(data);
      }
    });

  }

  void checkIfFollowing() {
    if (widget.canal.usersSuiviId!.contains(authProvider.loginUserData.id)) {
      setState(() {
        isFollowing = true;
      });
    }
  }

  Future<void> suivreCanal(Canal canal) async {
    final String userId = authProvider.loginUserData.id!;

    // Vérifier si l'utilisateur suit déjà le canal
    if (canal.usersSuiviId!.contains(userId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Vous suivez déjà ce canal.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.orange),
          ),
        ),
      );
      return;
    }

    // Ajouter l'utilisateur à la liste des abonnés
    canal.usersSuiviId!.add(userId);
    await firestore.collection('Canaux').doc(canal.id).update({
      'usersSuiviId': canal.usersSuiviId,
    });

    setState(() {
      isFollowing = true;
    });

    // Création de la notification
    NotificationData notif = NotificationData(
      id: firestore.collection('Notifications').doc().id,
      titre: "Canal 📺",
      media_url: authProvider.loginUserData.imageUrl,
      type: NotificationType.ACCEPTINVITATION.name,
      description:
      "@${authProvider.loginUserData.pseudo!} suit votre canal #${canal.titre!} 📺!",
      users_id_view: [],
      user_id: userId,
      receiver_id: canal.userId!,
      post_id: "",
      post_data_type: "",
      updatedAt: DateTime.now().microsecondsSinceEpoch,
      createdAt: DateTime.now().microsecondsSinceEpoch,
      status: PostStatus.VALIDE.name,
    );

    await firestore.collection('Notifications').doc(notif.id).set(notif.toJson());

    // Envoi de la notification
    await authProvider.sendNotification(
      userIds: [canal.user!.oneIgnalUserid!],
      smallImage: canal.urlImage!,
      send_user_id: userId,
      recever_user_id: canal.userId!,
      message:
      "📢📺 @${authProvider.loginUserData.pseudo!} suit votre canal #${canal.titre!} 📺!",
      type_notif: NotificationType.ACCEPTINVITATION.name,
      post_id: "",
      post_type: "",
      chat_id: "",
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Vous suivez maintenant ce canal.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.green),
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    _changeColor();
    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(color: Colors.white),
        title: Text(widget.canal.titre!, style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(onPressed: () {
            setState(() {
              checkIfFollowing();
              postProvider.getCanalPosts(100,widget.canal).listen((data) {
                if (!_streamController.isClosed) {
                  _streamController.add(data);
                }
              });
            });

          }, icon: Icon(Icons.refresh))
        ],
        backgroundColor: Colors.green,
      ),
      body:SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          slivers: <Widget>[
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              sliver: SliverToBoxAdapter(
                child: Stack(
                  children: [
                    GestureDetector(
                      onTap: () {
                        showImageDetailsModalDialog(widget.canal.urlCouverture!, width, height,context);

                      },
                      child: Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: widget.canal.urlCouverture != null
                                ? NetworkImage(widget.canal.urlCouverture!)
                                : AssetImage('assets/default_cover.png') as ImageProvider,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 16,
                      child: GestureDetector(
                        onTap: () {
                          showImageDetailsModalDialog(widget.canal.urlImage!, width, height,context);

                        },
                        child: CircleAvatar(
                          radius: 50,
                          backgroundImage: widget.canal.urlImage != null
                              ? NetworkImage(widget.canal.urlImage!)
                              : AssetImage('assets/default_profile.png') as ImageProvider,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              sliver: SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 170,
                            child: Text(
                              "#${widget.canal.titre!}",
                              style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Visibility(
                            visible: widget.canal.isVerify == null || widget.canal.isVerify == false ? false : true,
                            child: Card(
                              child: const Icon(
                                Icons.verified,
                                color: Colors.blue,
                                size: 30,
                              ),
                            ),
                          ),

                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,

                        children: [
                          Text(
                            'Abonnés: ${widget.canal.usersSuiviId!.length}',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),

                          authProvider.loginUserData!.id!=widget.canal.userId?SizedBox.shrink(): ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => ChannelFollowersPage(userIds: widget.canal.usersSuiviId!)),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                            child: Row(
                              children: [
                                Text('Voir mes abonnés', style: TextStyle(fontSize: 16, color: Colors.white)),
                                SizedBox(width: 10),
                                Icon(Icons.remove_red_eye_rounded, color: Colors.white),
                              ],
                            ),
                          ),

                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          isFollowing
                              ? SizedBox.shrink()
                              : ElevatedButton(
                            onPressed: () {
                              suivreCanal(widget.canal);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                            child: Text('Suivre', style: TextStyle(fontSize: 16, color: Colors.white)),
                          ),
                         authProvider.loginUserData!.id!=widget.canal.userId?SizedBox.shrink(): ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => EditCanal(canal: widget.canal)),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.brown,
                            ),
                            child: Row(
                              children: [
                                Text('Modifier', style: TextStyle(fontSize: 16, color: Colors.white)),
                                SizedBox(width: 10),
                                Icon(Icons.edit, color: Colors.white),
                              ],
                            ),
                          ),
                          authProvider.loginUserData!.id!=widget.canal.userId?SizedBox.shrink(): ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => CanalPostForm(canal: widget.canal)),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                            child: Row(
                              children: [
                                Text('Poster', style: TextStyle(fontSize: 16, color: Colors.white)),
                                SizedBox(width: 10),
                                Icon(Icons.add, color: Colors.white),
                              ],
                            ),
                          ),

                        ],
                      ),
                      SizedBox(height: 16),
                      ExpansionTile(
                        title: Text("Description"),
                        children: [
                          Text(
                            widget.canal.description!,
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Posts',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            StreamBuilder<List<Post>>(
              stream: _streamController.stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return SliverToBoxAdapter(
                    child: Center(child: CircularProgressIndicator()),
                  );
                } else if (snapshot.hasError) {
                  return SliverToBoxAdapter(
                    child: Center(child: Icon(Icons.error)),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Center(child: Text('Pas de looks')),
                  );
                }else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                  List<Post> listConstposts = snapshot.data!;
                  return LiveSliverList(
                    controller: _scrollController,
                    showItemInterval: Duration(milliseconds: 10),
                    showItemDuration: Duration(milliseconds: 30),
                    itemCount: listConstposts.length,
                    itemBuilder: animationItemBuilder(
                          (index) {
                        return HomePostUsersWidget(
                          post: listConstposts[index], color: _color, height: height, width: width,
                        );
                      },
                      padding: EdgeInsets.symmetric(vertical: 8),
                    ),
                  );
                }
                return SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator()),
                );

              },
            ),
          ],
        ),
      ),
    );
  }
}