import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:afrotok/pages/story/afroStory/story2/storyComment.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_story_presenter/flutter_story_presenter.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../../../../providers/authProvider.dart';
import '../repository.dart';
import '../util.dart';



class Story2 extends StatefulWidget {
  final UserData userData;
  const Story2({super.key, required this.userData});

  @override
  State<Story2> createState() => _Story2State();
}

class _Story2State extends State<Story2> {
  PageController pageController = PageController();
  double currentPageValue = 0.0;
  List<StoryModel> convertToStoryModel(List<WhatsappStory> whatsappStories) {
    return whatsappStories.map((whatsappStory) {
      return StoryModel(
        userName: '@${widget.userData.pseudo}', // Remplacez par le nom d'utilisateur approprié
        userProfile: '${widget.userData.imageUrl}', // Remplacez par l'URL de l'image de profil appropriée
        stories: [
          StoryItem(
            vues: whatsappStory.nbrVues!,
            jaime: whatsappStory.jaimes!.length!,
            comment: whatsappStory.nbrComment==null?0:whatsappStory.nbrComment!,
            storyItemType: whatsappStory!.mediaType == MediaType.image
                ? StoryItemType.image
                : whatsappStory.mediaType == MediaType.video
                ? StoryItemType.video
                : StoryItemType.text,
            url:whatsappStory!.mediaType == MediaType.image? whatsappStory.media:"",
            duration: Duration(seconds: whatsappStory.duration?.toInt() ?? 5),
            textConfig: StoryViewTextConfig(
                textWidget:  Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    "${whatsappStory.caption}",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        fontStyle: FontStyle.italic),
                  ),
                ),
                backgroundWidget: whatsappStory!.mediaType == MediaType.text?Container(
                  decoration:  BoxDecoration(
      color: Color(int.parse("0x${whatsappStory.color!}"))
                      // gradient: LinearGradient(
                      //     begin: Alignment.topCenter,
                      //     end: Alignment.bottomCenter,
                      //     colors: [
                      //       Colors.brown,
                      //       Colors.white,
                      //       Colors.green
                      //     ])
          ),
                ):Container()), dateAgo: whatsappStory.when,
            listVues: whatsappStory.vues!,
            jaimes: whatsappStory.jaimes!,
            createdAt: whatsappStory.createdAt,

            // caption: whatsappStory.caption,
            // Ajoutez d'autres configurations spécifiques ici
          ),
        ],
      );
    }).toList();
  }
  List<StoryModel> sampleStory = [];

  //Story Data
  // List<StoryModel> sampleStory2 = [
  //   StoryModel(
  //     userName: 'Kaival Patel',
  //     userProfile: 'https://avatars.githubusercontent.com/u/39383435?v=4',
  //     stories: [
  //       StoryItem(
  //         storyItemType: StoryItemType.custom,
  //         audioConfig: StoryViewAudioConfig(
  //           audioPath: 'https://audios.ftcdn.net/08/98/82/47/48K_898824706.m4a',
  //           source: StoryItemSource.network,
  //           onAudioStart: (p0) {},
  //         ),
  //         customWidget: (p0, audioPlayer) => AudioCustomView1(
  //           controller: p0,
  //           audioPlayer: audioPlayer,
  //         ),
  //       ),
  //       StoryItem(
  //         storyItemType: StoryItemType.image,
  //         url:
  //         "https://images.pexels.com/photos/3225517/pexels-photo-3225517.jpeg?auto=compress&cs=tinysrgb&w=800",
  //       ),
  //       StoryItem(
  //         storyItemType: StoryItemType.video,
  //         storyItemSource: StoryItemSource.asset,
  //         url: 'assets/fb8512a35d6f4b2e8917b74a048de71a.MP4',
  //         thumbnail: const Center(
  //             child: Row(
  //               mainAxisAlignment: MainAxisAlignment.center,
  //               children: [
  //                 CupertinoActivityIndicator(
  //                   radius: 15,
  //                 ),
  //                 SizedBox(
  //                   width: 10,
  //                 ),
  //                 Text('Video Loading')
  //               ],
  //             )),
  //         videoConfig: const StoryViewVideoConfig(
  //           fit: BoxFit.cover,
  //         ),
  //       ),
  //       StoryItem(
  //           storyItemType: StoryItemType.video,
  //           url:
  //           'https://videos.pexels.com/video-files/5913245/5913245-uhd_1440_2560_30fps.mp4',
  //           videoConfig: const StoryViewVideoConfig(
  //             fit: BoxFit.cover,
  //             height: double.infinity,
  //             width: double.infinity,
  //             loadingWidget: Center(child: CupertinoActivityIndicator()),
  //           )),
  //       StoryItem(
  //         storyItemType: StoryItemType.custom,
  //         duration: const Duration(seconds: 20),
  //         customWidget: (p0, audioPlayer) => PostOverlayView(
  //           controller: p0,
  //         ),
  //         imageConfig: StoryViewImageConfig(
  //           fit: BoxFit.contain,
  //           progressIndicatorBuilder: (p0, p1, p2) => const Center(
  //             child: CupertinoActivityIndicator(),
  //           ),
  //         ),
  //       ),
  //     ],
  //   ),
  //   StoryModel(
  //     userName: 'Lakhan P.',
  //     userProfile: 'https://devkrest.com/team/lakhan.png',
  //     stories: [
  //       StoryItem(
  //         storyItemType: StoryItemType.custom,
  //         duration: const Duration(seconds: 20),
  //         customWidget: (p0, audioPlayer) => PostOverlayView(
  //           controller: p0,
  //         ),
  //         imageConfig: StoryViewImageConfig(
  //           fit: BoxFit.contain,
  //           progressIndicatorBuilder: (p0, p1, p2) => const Center(
  //             child: CupertinoActivityIndicator(),
  //           ),
  //         ),
  //       ),
  //       StoryItem(
  //         storyItemType: StoryItemType.video,
  //         storyItemSource: StoryItemSource.asset,
  //         url: 'assets/StorySaver.net-_spindia_-Video-1718781607686.mp4',
  //         thumbnail: const Center(
  //             child: Row(
  //               mainAxisAlignment: MainAxisAlignment.center,
  //               children: [
  //                 CupertinoActivityIndicator(
  //                   radius: 15,
  //                 ),
  //                 SizedBox(
  //                   width: 10,
  //                 ),
  //                 Text('Video Loading')
  //               ],
  //             )),
  //         videoConfig: const StoryViewVideoConfig(
  //           fit: BoxFit.contain,
  //         ),
  //       ),
  //     ],
  //   ),
  //   StoryModel(
  //     userName: 'Harsh P.',
  //     userProfile: 'https://devkrest.com/team/harsh.jpg',
  //     stories: [
  //       StoryItem(
  //         storyItemType: StoryItemType.text,
  //         textConfig: StoryViewTextConfig(
  //             textWidget: const Text(
  //               "Happy Independence Day",
  //               style: TextStyle(
  //                   color: Colors.black,
  //                   fontWeight: FontWeight.bold,
  //                   fontSize: 24,
  //                   fontStyle: FontStyle.italic),
  //             ),
  //             backgroundWidget: Container(
  //               decoration: const BoxDecoration(
  //                   gradient: LinearGradient(
  //                       begin: Alignment.topCenter,
  //                       end: Alignment.bottomCenter,
  //                       colors: [
  //                         Colors.deepOrange,
  //                         Colors.white,
  //                         Colors.green
  //                       ])),
  //             )),
  //         url: "Happy Independence Day",
  //       ),
  //       StoryItem(
  //         storyItemType: StoryItemType.web,
  //         url:
  //         'https://www.ndtv.com/webstories/travel/10-things-to-do-in-amritsar-from-golden-temple-visit-to-wagah-border-47',
  //         duration: const Duration(seconds: 20),
  //         imageConfig: StoryViewImageConfig(
  //           fit: BoxFit.contain,
  //           progressIndicatorBuilder: (p0, p1, p2) => const Center(
  //             child: CupertinoActivityIndicator(),
  //           ),
  //         ),
  //       ),
  //     ],
  //   ),
  // ];

  @override
  void initState() {
    super.initState();
    sampleStory = convertToStoryModel(widget.userData.stories!);

  }

  multiStoryView() {}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        itemCount: sampleStory.length,
        // physics: const NeverScrollableScrollPhysics(),
        controller: pageController,
        itemBuilder: (context, index) {
          return AnimatedBuilder(
            animation: pageController,
            child: MyStoryView(
              storyModel: sampleStory[index],
              pageController: pageController,
              storyUser: widget.userData,
            ),
            builder: (context, child) {
              if (pageController.position.hasContentDimensions) {
                currentPageValue = pageController.page ?? 0.0;
                final isLeaving = (index - currentPageValue) <= 0;
                final t = (index - currentPageValue);
                final rotationY = lerpDouble(0, 30, t)!;
                const maxOpacity = 0.8;
                final num opacity =
                lerpDouble(0, maxOpacity, t.abs())!.clamp(0.0, maxOpacity);
                final isPaging = opacity != maxOpacity;
                final transform = Matrix4.identity();
                transform.setEntry(3, 2, 0.003);
                transform.rotateY(-rotationY * (pi / 180.0));
                return Transform(
                  alignment:
                  isLeaving ? Alignment.centerRight : Alignment.centerLeft,
                  transform: transform,
                  child: Stack(
                    children: [
                      child!,
                      if (isPaging && !isLeaving)
                        Positioned.fill(
                          child: Opacity(
                            opacity: opacity as double,
                            child: const ColoredBox(
                              color: Colors.black87,
                            ),
                          ),
                        )
                    ],
                  ),
                );
              }

              return child!;
            },
          );
        },
      ),
    );
  }
}

class MyStoryView extends StatefulWidget {
  const MyStoryView({
    super.key,
    required this.storyModel,
    required this.pageController, required this.storyUser,
  });

  final UserData storyUser;
  final StoryModel storyModel;
  final PageController pageController;

  @override
  State<MyStoryView> createState() => _MyStoryViewState();
}

class _MyStoryViewState extends State<MyStoryView> {
  late FlutterStoryController controller;
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  int indexStory=-1;
  int _currentPage=0;
  @override
  void initState() {
    controller = FlutterStoryController();

    super.initState();
  }

  @override
  void dispose() {
    // widget.pageController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storyViewIndicatorConfig = StoryViewIndicatorConfig(
      height: 4,
      activeColor: Colors.white,
      backgroundCompletedColor: Colors.white,
      backgroundDisabledColor: Colors.white.withOpacity(0.5),
      horizontalGap: 1,
      borderRadius: 1.5,
    );


    return FlutterStoryPresenter(
      flutterStoryController: controller,
      items: widget.storyModel.stories,
      footerWidget: MessageBoxView(controller: controller,
        storyItem: widget.storyModel.stories!.elementAt(_currentPage!)!,
        userConnected: authProvider.loginUserData, userStory: widget.storyUser,
        currentPage: _currentPage, authProvider: authProvider,
      ),
      storyViewIndicatorConfig: storyViewIndicatorConfig,
      initialIndex: 0,

      headerWidget: ProfileView(storyModel: widget.storyModel, storyItem: widget.storyModel.stories!.elementAt(_currentPage!)!, userStory: widget.storyUser,),

      onStoryChanged: (p0) {
        // indexStory++;
        //
        // printVm("index storie : ${indexStory}");
        //
        // widget.pageController.addListener(() {
        //
        //     _currentPage =  widget.pageController.page?.round() ?? 0;
        //     printVm('index page : ${_currentPage}');
        //
        // });


        _currentPage =  widget.pageController.page?.round() ?? 0;
        printVm('index page : ${_currentPage}');


      },
      onPreviousCompleted: () async {
        await widget.pageController.previousPage(
            duration: const Duration(milliseconds: 500),
            curve: Curves.decelerate);
      },
      onCompleted: () async {
        await widget.pageController.nextPage(
            duration: const Duration(milliseconds: 500),
            curve: Curves.decelerate);
        controller = FlutterStoryController();
      },
    );
  }
}

class MessageBoxView extends StatefulWidget {
   MessageBoxView({
    super.key,
    required this.controller, required this.storyItem,
     required this.userConnected, required this.userStory,
     required this.currentPage, required this.authProvider,
  });

  final UserAuthProvider authProvider;
  final FlutterStoryController controller;
  late StoryItem storyItem;
  final UserData userConnected;
  late  UserData userStory;
  final int currentPage;

  @override
  State<MessageBoxView> createState() => _MessageBoxViewState();
}

class _MessageBoxViewState extends State<MessageBoxView> {
  late int nbrJaime=0;
  late int nbrVues=0;
  late WhatsappStory whatsappStory;

  @override
  void initState() {
    printVm('widget.storyItem : ${widget.storyItem.createdAt}');

    widget.storyItem.vues=widget.storyItem.vues!+1;
   WhatsappStory story= widget.userStory.stories!.where((element) => element.createdAt==    widget.storyItem.createdAt,).first;
    setState(() {
      if(story!=null){
        int indexStory=widget.userStory.stories!.indexOf(story);
        story.nbrVues=widget.storyItem.vues;
        widget.userStory.stories![indexStory]=story;
        widget.authProvider.updateUser(widget.userStory);

      }

    });
    // TODO: implement initState
    // widget.authProvider.getUserById(widget.userStory.id!).then((value) {
    //   if(value.isNotEmpty){
    //     widget.userStory.stories![widget.currentPage].nbrVues=widget.userStory.stories![widget.currentPage].nbrVues!+1;
    //     widget.authProvider.updateUser(widget.userStory);
    //   }
    // },);
    super.initState();
  }
  @override
  Widget build(BuildContext context) {




    // printVm('storyItem _currentPage : ${jsonEncode(storyItem)}');
    return SafeArea(
      child: Padding(
        padding:
        const EdgeInsets.symmetric(horizontal: 10).copyWith(bottom: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                IconButton(
                    onPressed: () {},
                    iconSize: 25,
                    icon:  Padding(
                      padding: EdgeInsets.only(bottom: 9),
                      child: Icon(
                        Icons.remove_red_eye_rounded,
                        color: Colors.white,
                      ),
                    )
                ),
                Text("${widget.storyItem.vues!}",style: TextStyle(color: Colors.white),)
              ],
            ),
            Row(
              children: [
                IconButton(
                    onPressed: () async {
                      if(!widget.storyItem.jaimes!.any((element) => element==widget.userConnected.id)){

                        widget.storyItem.jaime=widget.storyItem.jaime!+1;
                        widget.storyItem.jaimes!.add(widget.userConnected.id!);

                        setState(()  {

                        });

                          WhatsappStory story=widget.userStory.stories!.where((element) => element.createdAt==widget.storyItem.createdAt,).first;

                          story.nbrJaimes=story.nbrJaimes!+1;
                          story.jaimes!.add(widget.authProvider.loginUserData.id!);
                          int indexStory= widget.userStory.stories!.indexOf(story);
                          widget.userStory.stories![indexStory]=story;
                          widget.authProvider.updateUser(widget.userStory);

                          await widget. authProvider.sendNotification(
                              userIds: [widget.userStory.oneIgnalUserid!],
                              smallImage: "${widget.authProvider.loginUserData.imageUrl!}",
                              send_user_id: "${widget.authProvider.loginUserData.id!}",
                              recever_user_id: "",
                              message: "📢 @${widget.authProvider.loginUserData.pseudo!} aime ❤️   votre  chronique 🎥✨ !",
                              type_notif: NotificationType.CHRONIQUE.name,
                              post_id: "id",
                              post_type: PostDataType.TEXT.name, chat_id: ''
                          );

                        }


                        // widget.authProvider.getUserById(widget.userStory.id!).then((value) async {
                        //   if(value.isNotEmpty){
                        //     widget.userStory=value.first;
                        //
                        //     if(!widget.storyItem.jaimes!.any((element) => element==widget.userConnected.id)){
                        //
                        //       WhatsappStory story=widget.userStory.stories!.where((element) => element.createdAt==widget.storyItem.createdAt,).first;
                        //
                        //       story.nbrJaimes=story.nbrJaimes!+1;
                        //       story.jaimes!.add(widget.authProvider.loginUserData.id!);
                        //      int indexStory= widget.userStory.stories!.indexOf(story);
                        //       widget.userStory.stories![indexStory]=story;
                        //       await widget. authProvider.sendNotification(
                        //           userIds: [widget.userStory.oneIgnalUserid!],
                        //           smallImage: "${widget.authProvider.loginUserData.imageUrl!}",
                        //           send_user_id: "${widget.authProvider.loginUserData.id!}",
                        //           recever_user_id: "",
                        //           message: "📢 @${widget.authProvider.loginUserData.pseudo!} aime ❤️   votre  chronique 🎥✨ !",
                        //           type_notif: NotificationType.CHRONIQUE.name,
                        //           post_id: "id",
                        //           post_type: PostDataType.TEXT.name, chat_id: ''
                        //       );
                        //
                        //       widget.authProvider.updateUser(widget.userStory);
                        //     }
                        //   }
                        // },);




                    },
                    iconSize: 25,
                    icon:  Padding(
                      padding: EdgeInsets.only(bottom: 9),
                      child: Icon(
                        widget.storyItem.jaimes!.any((element) => element==widget.userConnected.id)?  AntDesign.heart:AntDesign.hearto,
                        // AntDesign.hearto
                        color: Colors.red,
                      ),
                    )
                ),
                Text("${widget.storyItem.jaime!}",style: TextStyle(color: Colors.white),)
              ],
            ),
            Row(
              children: [
                IconButton(
                    onPressed: () {},
                    iconSize: 25,
                    icon:  Padding(
                      padding: EdgeInsets.only(bottom: 9),
                      child: Icon(
                        FontAwesome.commenting,
                        // AntDesign.hearto
                        color: Colors.white,
                      ),
                    )
                ),
                Text("${widget.storyItem.comment??0}",style: TextStyle(color: Colors.white),)
              ],
            ),
            SizedBox(width: 10,),

            // IconButton(onPressed: () {
            //
            // }, icon: Icon(Icons.more_horiz,size: 30,color: Colors.white,)),
            // SizedBox(width: 10,),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  widget.controller.pause();
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (BuildContext context) {
                      return FractionallySizedBox(
                        heightFactor: 0.8, // 90% de la hauteur de l'écran
                        child: Container(
                          color: Colors.white,
                          child: StoryComments(story: widget.storyItem, userStory: widget.userStory,),
                        ),
                      );
                    },
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.white,
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Padding(
                    padding: const EdgeInsets.all(2.0),
                    child: Text('Commentez la chronique',style: TextStyle(color: Colors.white),),
                  ),
                ),
              ),
            ),
            const SizedBox(
              width: 5,
            ),
            // IconButton(
            //     onPressed: () {},
            //     iconSize: 30,
            //     icon: Transform.rotate(
            //         angle: -0.6,
            //         child: const Padding(
            //           padding: EdgeInsets.only(bottom: 9),
            //           child: Icon(
            //             Icons.send,
            //             color: Colors.white,
            //           ),
            //         )))
          ],
        ),
      ),
    );
  }
}

class ProfileView extends StatelessWidget {
   ProfileView({
    super.key,
    required this.storyModel, required this.storyItem, required this.userStory,
  });

  final StoryModel storyModel;
  final StoryItem storyItem;
  final UserData userStory;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(1),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 30, left: 15, right: 15),
        child: Row(
          children: [
            Container(
              decoration: const BoxDecoration(
                color: Colors.amber,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(1),
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: storyModel.userProfile,
                  height: 35,
                  width: 35,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(
              width: 10,
            ),
            Expanded(
              child:     Row(
                children: [
                  SizedBox(

                    width: 80,
                    child: Text(
                      storyModel.userName,
                      overflow: TextOverflow.ellipsis, // Ajout de cette ligne
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  // const SizedBox(
                  //   width: 5,
                  // ),
                  // SizedBox(width: 5,),
                  Visibility(
                    visible: userStory.isVerify!,
                    child: const Icon(
                      Icons.verified,
                      color: Colors.green,
                      size: 20,
                    ),
                  ),
                  // const Icon(
                  //   Icons.verified,
                  //   size: 15,
                  // ),
                  const SizedBox(
                    width: 5,
                  ),

                  Text(
                    '${storyItem.dateAgo!}',
                    style: TextStyle(color: Colors.white, fontSize: 10),
                  )

                ],
              ),
            ),
            Text(
              '@Afrolook',
              style: TextStyle(color: Colors.greenAccent, fontSize: 20,fontWeight: FontWeight.w900),
            ),
            // IconButton(
            //   onPressed: () {},
            //   icon: const Icon(
            //     Icons.more_horiz,
            //     color: Colors.white,
            //   ),
            // )
          ],
        ),
      ),
    );
  }
}

// Custom Story Data Model
class StoryModel {
  String userName;
  String userProfile;
  List<StoryItem> stories;

  StoryModel({
    required this.userName,
    required this.userProfile,
    required this.stories,
  });
}

// Custom Widget - Question
class TextOverlayView extends StatelessWidget {
  const TextOverlayView({super.key, required this.controller});

  final FlutterStoryController? controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      decoration: const BoxDecoration(
          image: DecorationImage(
              fit: BoxFit.cover,
              image: CachedNetworkImageProvider(
                  'https://images.pexels.com/photos/1761279/pexels-photo-1761279.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=2'))),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        spreadRadius: 0,
                      )
                    ]),
                child: Column(
                  children: [
                    const SizedBox(
                      height: 20,
                    ),
                    const Text(
                      "What’s your favorite outdoor activity and why?",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: IntrinsicWidth(
                        child: TextFormField(
                          onTap: () {
                            controller?.pause();
                          },
                          onTapOutside: (event) {
                            // controller?.play();
                            FocusScope.of(context).unfocus();
                          },
                          style: const TextStyle(
                            color: Colors.black,
                          ),
                          decoration: InputDecoration(
                              hintText: 'Type something...',
                              hintStyle: TextStyle(
                                color: Colors.black.withOpacity(0.6),
                              ),
                              border: InputBorder.none),
                        ),
                      ),
                    )
                  ],
                ),
              ),
              Positioned(
                top: -40,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                      color: const Color(0xffE2DCFF),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                        )
                      ]),
                  padding: const EdgeInsets.all(20),
                  child: CachedNetworkImage(
                    imageUrl: 'https://devkrest.com/logo/devkrest_outlined.png',
                    height: 40,
                    width: 40,
                  ),
                ),
              )
            ],
          ),
        ],
      ),
    );
  }
}

// Custom Widget - Post View
class PostOverlayView extends StatelessWidget {
  const PostOverlayView({super.key, required this.controller});

  final FlutterStoryController? controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      decoration: const BoxDecoration(
          gradient:
          LinearGradient(colors: [Color(0xffff8800), Color(0xffff3300)])),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 5),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 0,
                    spreadRadius: 0,
                  )
                ]),
            child: IntrinsicWidth(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          decoration: const BoxDecoration(
                            color: Color(0xffE2DCFF),
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(8),
                          child: CachedNetworkImage(
                            imageUrl:
                            'https://devkrest.com/logo/devkrest_outlined.png',
                            height: 15,
                            width: 15,
                          ),
                        ),
                        const SizedBox(
                          width: 8,
                        ),
                        const Expanded(
                          child: Text(
                            'devkrest',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(
                            Icons.more_horiz,
                          ),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(
                    height: 5,
                  ),
                  CachedNetworkImage(
                      height: MediaQuery.of(context).size.height * 0.40,
                      fit: BoxFit.cover,
                      imageUrl:
                      'https://scontent.cdninstagram.com/v/t51.29350-15/448680084_2197193763952189_5110658492947027914_n.webp?stp=dst-jpg_e35&efg=eyJ2ZW5jb2RlX3RhZyI6ImltYWdlX3VybGdlbi4xNDQweDE4MDAuc2RyLmYyOTM1MCJ9&_nc_ht=scontent.cdninstagram.com&_nc_cat=1&_nc_ohc=VtYwOfs3y44Q7kNvgEfDjM0&edm=APs17CUBAAAA&ccb=7-5&ig_cache_key=MzM5MzIyNzQ4MjcwNjA5NzYzNQ%3D%3D.2-ccb7-5&oh=00_AYAEOmKhroMeZensvVXMuCbC8rB0vr_0P7-ecR8AKLk5Lw&oe=6678548B&_nc_sid=10d13b'),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    child: Text(
                      "India vs Afganistan",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w400,
                          fontSize: 18,
                          fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Widget - Audio View - 1
class AudioCustomView1 extends StatelessWidget {
  const AudioCustomView1(
      {super.key, required this.controller, this.audioPlayer});

  final FlutterStoryController? controller;
  final AudioPlayer? audioPlayer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      decoration: const BoxDecoration(
          image: DecorationImage(
              fit: BoxFit.cover,
              image: CachedNetworkImageProvider(
                  'https://images.pexels.com/photos/1761279/pexels-photo-1761279.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=2'))),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            height: 130,
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                )
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'assets/img.png',
                        height: 50,
                        width: 50,
                        fit: BoxFit.cover,
                      ),
                    ),
                    StreamBuilder<bool>(
                        stream: audioPlayer?.playingStream,
                        builder: (context, snapshot) {
                          if (snapshot.data == false) {
                            return const SizedBox();
                          }
                          return Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: Colors.black.withOpacity(0.54),
                            ),
                            height: 50,
                            width: 50,
                            padding: const EdgeInsets.all(5),
                            child: Image.asset(
                              'assets/audio-anim__.gif',
                              fit: BoxFit.cover,
                            ),
                          );
                        })
                  ],
                ),
                const SizedBox(
                  width: 10,
                ),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Don't Give Up on Me",
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "Andy grammer",
                        style: TextStyle(
                          color: Colors.black.withOpacity(0.5),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(
                  width: 10,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
