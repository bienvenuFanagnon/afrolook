import 'package:afrotok/pages/userPosts/postPhotoEditor.dart';
import 'package:afrotok/pages/userPosts/postTabs/userPostImageTab.dart';
import 'package:afrotok/pages/userPosts/postTabs/userPostTextTab.dart';
import 'package:afrotok/pages/userPosts/postTabs/userPostVideoTab.dart';
// import 'package:afrotok/pages/userPosts/userPubTabs.dart';
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

  // Couleurs personnalisées
  final Color _primaryColor = Color(0xFFE21221); // Rouge
  final Color _secondaryColor = Color(0xFFFFD600); // Jaune
  final Color _backgroundColor = Color(0xFF121212); // Noir
  final Color _cardColor = Color(0xFF1E1E1E);
  final Color _textColor = Colors.white;
  final Color _hintColor = Colors.grey[400]!;

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _cardColor,
        elevation: 0,
        title: Text(
          "Créer une publication",
          style: TextStyle(
            color: _textColor,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Logo(),
          )
        ],
        iconTheme: IconThemeData(color: _textColor),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Carte utilisateur
              Container(
                padding: EdgeInsets.all(16),
                margin: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _primaryColor, width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 28,
                        backgroundImage: NetworkImage(
                            '${authProvider.loginUserData!.imageUrl}'),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "@${authProvider.loginUserData!.pseudo}",
                            style: TextStyle(
                              color: _textColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.people, color: _secondaryColor, size: 16),
                              SizedBox(width: 4),
                              Text(
                                "${authProvider.loginUserData!.userAbonnesIds!.length} abonné(s)",
                                style: TextStyle(
                                  color: _hintColor,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _primaryColor),
                      ),
                      child: Text(
                        'Créateur',
                        style: TextStyle(
                          color: _primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16),

              // Onglets
              Container(
                width: width,
                height: height * 0.78,
                margin: EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ContainedTabBarView(
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.text_fields, size: 20, color: _textColor),
                          SizedBox(width: 8),
                          Text(
                            "Pensée",
                            style: TextStyle(
                              color: _textColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.photo, size: 20, color: _textColor),
                          SizedBox(width: 8),
                          Text(
                            "Image",
                            style: TextStyle(
                              color: _textColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.videocam, size: 20, color: _textColor),
                          SizedBox(width: 8),
                          Text(
                            "Vidéo",
                            style: TextStyle(
                              color: _textColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  tabBarProperties: TabBarProperties(
                    height: 50.0,
                    indicatorColor: _primaryColor,
                    indicatorWeight: 3.0,
                    labelColor: _textColor,
                    unselectedLabelColor: _hintColor,
                    background: Container(
                      decoration: BoxDecoration(
                        color: _cardColor,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                    ),
                  ),
                  views: [
                    UserPubText(canal: null),
                    UserPostLookImageTab(canal: null,),
                    // UserPubImage(),
                    UserPubVideo(canal: null),
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
//
// class UserPostForm extends StatefulWidget {
//
//   const UserPostForm({super.key});
//
//   @override
//   State<UserPostForm> createState() => _UserProfilState();
// }
//
// class _UserProfilState extends State<UserPostForm> {
//   late UserAuthProvider authProvider =
//   Provider.of<UserAuthProvider>(context, listen: false);
//
//   late UserProvider userProvider =
//   Provider.of<UserProvider>(context, listen: false);
//   final FirebaseFirestore firestore = FirebaseFirestore.instance;
//
//   @override
//   Widget build(BuildContext context) {
//     double height = MediaQuery.of(context).size.height;
//     double width = MediaQuery.of(context).size.width;
//     return Scaffold(
//       backgroundColor: ConstColors.backgroundColor,
//       appBar: AppBar(
//         title: TextCustomerPageTitle(
//           titre: "Poster votre look",
//           fontSize: SizeText.homeProfileTextSize,
//           couleur: ConstColors.textColors,
//           fontWeight: FontWeight.bold,
//         ),
//
//
//
//         //backgroundColor: Colors.blue,
//         actions: [
//           Padding(
//             padding: const EdgeInsets.only(right: 8.0),
//             child: Logo(),
//           )
//         ],
//         //title: Text(widget.title),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(8.0),
//         child: SingleChildScrollView(
//           child: Column(
//
//             children: [
//               Padding(
//                 padding: const EdgeInsets.only(bottom: 8.0),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Row(
//                       children: [
//                         Padding(
//                           padding: const EdgeInsets.only(right: 15.0),
//                           child: CircleAvatar(
//                             radius: 30,
//                             backgroundImage: NetworkImage(
//                                 '${authProvider.loginUserData!.imageUrl}'),
//                           ),
//                         ),
//                         SizedBox(
//                           height: 2,
//                         ),
//                         Row(
//                           children: [
//                             Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 SizedBox(
//                                   //width: 100,
//                                   child: TextCustomerUserTitle(
//                                     titre: "@${authProvider.loginUserData!.pseudo}",
//                                     fontSize: SizeText.homeProfileTextSize,
//                                     couleur: ConstColors.textColors,
//                                     fontWeight: FontWeight.bold,
//                                   ),
//                                 ),
//                                 TextCustomerUserTitle(
//                                   titre: "${authProvider.loginUserData!.userAbonnesIds!.length} abonné(s)",
//                                   fontSize: SizeText.homeProfileTextSize,
//                                   couleur: ConstColors.textColors,
//                                   fontWeight: FontWeight.w400,
//                                 ),
//                               ],
//                             ),
//
//                           ],
//                         ),
//                       ],
//                     ),
//                     Padding(
//                       padding: const EdgeInsets.only(right: 12.0),
//                       child: Column(
//                         children: [
//
//
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               SizedBox(
//                 height: 10,
//
//               ),
//
//               SizedBox(
//                 width: width,
//                 height:height*0.86 ,
//                 child: ContainedTabBarView(
//                   tabs: [
//                     Container(
//                       child: TextCustomerMenu(
//                         titre: "Pensée",
//                         fontSize: SizeText.homeProfileTextSize,
//                         couleur: ConstColors.textColors,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                     Container(
//                       child: TextCustomerMenu(
//                         titre: "Image",
//                         fontSize: SizeText.homeProfileTextSize,
//                         couleur: ConstColors.textColors,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                     Container(
//                       child: TextCustomerMenu(
//                         titre: "Vidéo",
//                         fontSize: SizeText.homeProfileTextSize,
//                         couleur: ConstColors.textColors,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                   ],
//                   tabBarProperties: TabBarProperties(
//                     height: 32.0,
//                     indicatorColor: ConstColors.menuItemsColors,
//                     indicatorWeight: 6.0,
//                     labelColor: Colors.black,
//                     unselectedLabelColor: Colors.grey[400],
//                   ),
//                   views: [
//
//                     Padding(
//                       padding: const EdgeInsets.only(top: 8.0),
//                       child: UserPubText(canal: null,),
//                       // child: HashTagHomeView(),
//                     ),
//                     Padding(
//                       padding: const EdgeInsets.only(top: 8.0),
//                       // child: UserPubImage(),
//                       child: PostPhotoEditor(canal: null,),
//                     ),
//                     Padding(
//                         padding: const EdgeInsets.only(top: 8.0),
//                         child: UserPubVideo(canal: null,)),
//                   ],
//                   onChange: (index) => printVm(index),
//                 ),
//               ),
//
//             ],
//           ),
//
//         ),
//       ),
//     );
//   }
// }
