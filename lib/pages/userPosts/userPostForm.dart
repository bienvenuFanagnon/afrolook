import 'package:afrotok/pages/userPosts/postPhotoEditor.dart';
import 'package:afrotok/pages/userPosts/userPubTabs.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:contained_tab_bar_view_with_custom_page_navigator/contained_tab_bar_view_with_custom_page_navigator.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../constant/buttons.dart';
import '../../../constant/constColors.dart';
import '../../../constant/iconGradient.dart';
import '../../../constant/listItemsCarousel.dart';
import '../../../constant/logo.dart';
import '../../../constant/sizeText.dart';
import '../../../constant/textCustom.dart';
import '../../providers/authProvider.dart';
import '../../providers/userProvider.dart';
import '../component/consoleWidget.dart';
import 'hashtag/textHashTag/hashtaHomeView.dart';

class UserPostForm extends StatefulWidget {

  const UserPostForm({super.key});

  @override
  State<UserPostForm> createState() => _UserProfilState();
}

class _UserProfilState extends State<UserPostForm> {
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);

  late UserProvider userProvider =
  Provider.of<UserProvider>(context, listen: false);
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: ConstColors.backgroundColor,
      appBar: AppBar(
        title: TextCustomerPageTitle(
          titre: "Poster votre look",
          fontSize: SizeText.homeProfileTextSize,
          couleur: ConstColors.textColors,
          fontWeight: FontWeight.bold,
        ),



        //backgroundColor: Colors.blue,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Logo(),
          )
        ],
        //title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SingleChildScrollView(
          child: Column(

            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 15.0),
                          child: CircleAvatar(
                            radius: 30,
                            backgroundImage: NetworkImage(
                                '${authProvider.loginUserData!.imageUrl}'),
                          ),
                        ),
                        SizedBox(
                          height: 2,
                        ),
                        Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  //width: 100,
                                  child: TextCustomerUserTitle(
                                    titre: "@${authProvider.loginUserData!.pseudo}",
                                    fontSize: SizeText.homeProfileTextSize,
                                    couleur: ConstColors.textColors,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextCustomerUserTitle(
                                  titre: "${authProvider.loginUserData!.userAbonnesIds!.length} abonné(s)",
                                  fontSize: SizeText.homeProfileTextSize,
                                  couleur: ConstColors.textColors,
                                  fontWeight: FontWeight.w400,
                                ),
                              ],
                            ),

                          ],
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 12.0),
                      child: Column(
                        children: [


                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 10,

              ),

              SizedBox(
                width: width,
                height:height*0.86 ,
                child: ContainedTabBarView(
                  tabs: [
                    Container(
                      child: TextCustomerMenu(
                        titre: "Pensée",
                        fontSize: SizeText.homeProfileTextSize,
                        couleur: ConstColors.textColors,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Container(
                      child: TextCustomerMenu(
                        titre: "Image",
                        fontSize: SizeText.homeProfileTextSize,
                        couleur: ConstColors.textColors,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Container(
                      child: TextCustomerMenu(
                        titre: "Vidéo",
                        fontSize: SizeText.homeProfileTextSize,
                        couleur: ConstColors.textColors,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  tabBarProperties: TabBarProperties(
                    height: 32.0,
                    indicatorColor: ConstColors.menuItemsColors,
                    indicatorWeight: 6.0,
                    labelColor: Colors.black,
                    unselectedLabelColor: Colors.grey[400],
                  ),
                  views: [

                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: UserPubText(canal: null,),
                      // child: HashTagHomeView(),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      // child: UserPubImage(),
                      child: PostPhotoEditor(canal: null,),
                    ),
                    Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: UserPubVideo(canal: null,)),
                  ],
                  onChange: (index) => printVm(index),
                ),
              ),

            ],
          ),

        ),
      ),
    );
  }
}
