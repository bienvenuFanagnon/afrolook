import 'package:afrotok/pages/canaux/newCanal.dart';
import 'package:afrotok/pages/user/profile/postsMonetisation.dart';
import 'package:afrotok/pages/user/profile/profileTabsBar/tabBar.dart';
import 'package:afrotok/pages/user/monetisation.dart';
import 'package:contained_tab_bar_view_with_custom_page_navigator/contained_tab_bar_view_with_custom_page_navigator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:provider/provider.dart';

import '../../../constant/buttons.dart';
import '../../../constant/constColors.dart';

import '../../../constant/logo.dart';
import '../../../constant/sizeText.dart';
import '../../../constant/textCustom.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/postProvider.dart';
import '../../../providers/userProvider.dart';
import '../../canaux/listCanal.dart';
import '../../canaux/listCanauxByUser.dart';

class UserProfil extends StatefulWidget {
  const UserProfil({super.key});

  @override
  State<UserProfil> createState() => _UserProfilState();
}

class _UserProfilState extends State<UserProfil> {

  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  late UserProvider userProvider =
  Provider.of<UserProvider>(context, listen: false);

  late PostProvider postProvider =
  Provider.of<PostProvider>(context, listen: false);
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

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: ConstColors.backgroundColor,
      appBar: AppBar(
        title: TextCustomerPageTitle(
          titre: "Mon Profile",
          fontSize: SizeText.homeProfileTextSize,
          couleur: ConstColors.textColors,
          fontWeight: FontWeight.bold,
        ),

        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Logo(),
          )
        ],
        //title: Text(widget.title),
      ),
      body: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Container(
          height: height*1.28,

          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisSize: MainAxisSize.max,
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
                                  '${authProvider.loginUserData!.imageUrl!}'),
                            ),
                          ),
                          SizedBox(
                            height: 2,
                          ),
                          Row(
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment:CrossAxisAlignment.start ,
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
                                    titre: "${formatNumber(authProvider.loginUserData!.abonnes!)} abonné(s)",
                                    fontSize: SizeText.homeProfileTextSize,
                                    couleur: ConstColors.textColors,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  TextCustomerUserTitle(
                                    titre:
                                    "${formatNumber(authProvider.loginUserData!.userlikes!)} like(s)",
                                    fontSize: SizeText.homeProfileTextSize,
                                    couleur: Colors.green,
                                    fontWeight: FontWeight.w700,
                                  ),

                                ],
                              ),

                            ],
                          ),
                        ],
                      ),
                      /*
                      Padding(
                        padding: const EdgeInsets.only(right: 12.0),
                        child: Column(
                          children: [
                            SizedBox(
                              //width: 100,
                              child: TextCustomerUserTitle(
                                titre: "PubliCach",
                                fontSize: SizeText.homeProfileTextSize,
                                couleur: ConstColors.textColors,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextCustomerUserTitle(
                              titre: "500",
                              fontSize: SizeText.homeProfileTextSize,
                              couleur: ConstColors.textColors,
                              fontWeight: FontWeight.w400,
                            ),
                            SizedBox(height: 2,),
                            AchatPubliCachButton(),

                          ],
                        ),
                      ),

                       */
                    ],
                  ),
                ),
                SizedBox(
                  height: 10,

                ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Container(
                          child: TextCustomerUserTitle(
                            titre: "${authProvider.loginUserData!.mesPubs}",
                            fontSize: SizeText.homeProfileTextSize,
                            couleur: ConstColors.textColors,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Container(
                          child: TextCustomerUserTitle(
                            titre: "Mes Publications ",
                            fontSize: SizeText.homeProfileTextSize,
                            couleur: ConstColors.textColors,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Container(
                          child: TextCustomerUserTitle(
                            titre: "${authProvider.loginUserData!.pubEntreprise}",
                            fontSize: SizeText.homeProfileTextSize,
                            couleur: ConstColors.textColors,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Container(
                          child: TextCustomerUserTitle(
                            titre: "Publications Entreprises ",
                            fontSize: SizeText.homeProfileTextSize,
                            couleur: ConstColors.textColors,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(
                  height: 30,

                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                   // mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () {
                                Navigator.pushNamed(context, '/profil_detail_user');
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.only(topRight: Radius.circular(50),bottomRight: Radius.circular(50)),
                                child: Container(
                                  color: ConstColors.buttonsColors,
                                  // alignment: Alignment.centerLeft,
                                  width: 180,
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Row(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(right: 5.0),
                                          child: Container(
                                            child: Image.asset(
                                              'assets/icon/info.png',
                                              height: 20,
                                              width: 20,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          child: TextCustomerMenu(
                                            titre: "Mes Informations",
                                            fontSize: SizeText.homeProfileTextSize,
                                            couleur: ConstColors.textColors,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        )
                                      ],

                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 10,),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.only(topRight: Radius.circular(50),bottomRight: Radius.circular(50)),
                                  child: Container(
                                    color: ConstColors.buttonsColors,
                                    // alignment: Alignment.centerLeft,
                                    width: 180,
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Row(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(right: 5.0),
                                            child: Container(
                                              child: Image.asset(
                                                'assets/icon/entreprise.png',
                                                height: 20,
                                                width: 20,
                                              ),
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () {
                                              if(authProvider.loginUserData!.hasEntreprise!){
                                                userProvider.getUserEntreprise(authProvider.loginUserData.id!).then((value) {
                                                  if (value) {
                                                    Navigator.pushNamed(context, '/profile_entreprise');
                                                  }else{
                                                    Navigator.pushNamed(context, '/new_entreprise');
                                                  }

                                                },);

                                              }
                                            },
                                            child: Container(
                                              child: TextCustomerMenu(
                                                titre: "Mon Entreprise",
                                                fontSize: SizeText.homeProfileTextSize,
                                                couleur: ConstColors.textColors,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          )
                                        ],

                                      ),
                                    ),
                                  ),
                                ),


                                GestureDetector(
                                  onTap: () {

                                          Navigator.pushNamed(context, '/new_entreprise');


                                  },
                                  child:authProvider.loginUserData!.hasEntreprise!?Container(): Container(
                                    child: TextCustomerMenu(
                                      titre: "Creer",
                                      fontSize: SizeText.homeProfileTextSize,
                                      couleur: Colors.red,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                )
                              ],
                            ),
                            SizedBox(height: 10,),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => MonetisationPage(),));
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.only(topRight: Radius.circular(50),bottomRight: Radius.circular(50)),
                                child: Container(
                                  color: ConstColors.buttonsColors,
                                  // alignment: Alignment.centerLeft,
                                  width: 180,
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Row(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(right: 5.0),
                                          child: Container(
                                            child: Image.asset(
                                              'assets/icon/monetization.png',
                                              height: 20,
                                              width: 20,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          child: TextCustomerMenu(
                                            titre: "Monétisation",
                                            fontSize: SizeText.homeProfileTextSize,
                                            couleur: ConstColors.textColors,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        )
                                      ],
                              
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 10,),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => CanalListPageByUser(isUserCanals: true,),));
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.only(topRight: Radius.circular(50),bottomRight: Radius.circular(50)),
                                child: Container(
                                  color: ConstColors.buttonsColors,
                                  // alignment: Alignment.centerLeft,
                                  width: 180,
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Row(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(right: 5.0),
                                          child: Container(
                                            child: Icon(FontAwesome.forumbee,size: 20,color: Colors.green,),
                                          ),
                                        ),
                                        Container(
                                          child: TextCustomerMenu(
                                            titre: "Mes Canaux",
                                            fontSize: SizeText.homeProfileTextSize,
                                            couleur: ConstColors.textColors,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        )
                                      ],

                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // SizedBox(height: 10,),
                            // GestureDetector(
                            //   onTap: () {
                            //     Navigator.push(context, MaterialPageRoute(builder: (context) => PostsMonetiserPage(title: '',),));
                            //   },
                            //   child: ClipRRect(
                            //     borderRadius: BorderRadius.only(topRight: Radius.circular(50),bottomRight: Radius.circular(50)),
                            //     child: Container(
                            //       color: ConstColors.buttonsColors,
                            //       // alignment: Alignment.centerLeft,
                            //       width: 180,
                            //       child: Padding(
                            //         padding: const EdgeInsets.all(8.0),
                            //         child: Row(
                            //           children: [
                            //             Padding(
                            //               padding: const EdgeInsets.only(right: 5.0),
                            //               child: Container(
                            //                 child: Icon(FontAwesome.money,size: 20,color: Colors.green,),
                            //               ),
                            //             ),
                            //             Container(
                            //               child: TextCustomerMenu(
                            //                 titre: "Posts Monetiser",
                            //                 fontSize: SizeText.homeProfileTextSize,
                            //                 couleur: ConstColors.textColors,
                            //                 fontWeight: FontWeight.w600,
                            //               ),
                            //             )
                            //           ],
                            //
                            //         ),
                            //       ),
                            //     ),
                            //   ),
                            // ),
                            SizedBox(height: 10,),
                            ClipRRect(
                              borderRadius: BorderRadius.only(topRight: Radius.circular(50),bottomRight: Radius.circular(50)),
                              child: Container(
                                color: ConstColors.buttonsColors,
                                // alignment: Alignment.centerLeft,
                                width: 180,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Row(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(right: 5.0),
                                        child: Container(
                                          child: Image.asset(
                                            'assets/icon/entrepriseContact.png',
                                            height: 20,
                                            width: 20,
                                          ),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          Navigator.pushNamed(context, '/list_conversation_user_entreprise');
                                        },
                                        child: Container(
                                          child: TextCustomerMenu(
                                            titre: "Entreprise Contacté",
                                            fontSize: SizeText.homeProfileTextSize,
                                            couleur: ConstColors.textColors,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      )
                                    ],

                                  ),
                                ),
                              ),
                            ),

                          ],
                        ),
                      ),

                    ],
                  ),
                ),
                SizedBox(
                  height: 10,

                ),
                    Flexible(

                      child: SizedBox(
                        //width: width,
                        //height:height*0.86 ,
                        child: ContainedTabBarView(
                          tabs: [
                        Container(
                        child: TextCustomerMenu(
                        titre: "Mes Postes",
                          fontSize: SizeText.homeProfileTextSize,
                          couleur: ConstColors.textColors,
                          fontWeight: FontWeight.w600,
                        ),
                        ),
                            Container(
                        child: TextCustomerMenu(
                          titre: "Pubs Entreprises",
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
                              child: UserPublicationView(),
                            ),
                            Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: EntreprisePublicationView()),
                          ],
                          onChange: (index) => print(index),
                        ),
                      ),
                    ),

              ],
            ),
          ),
        ),
      ),
    );
  }
}
