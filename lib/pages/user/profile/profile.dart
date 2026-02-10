import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/canaux/newCanal.dart';
import 'package:afrotok/pages/tiktokProjet/tiktokPages.dart';
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
import '../../challenge/challengeDashbord.dart';
import '../../tiktokProjet/userTiktokVide.dart';
import '../../userPosts/favorites_posts.dart';
import '../otherUser/otherUser.dart';
import '../userAbonnementPage.dart';
import 'adminprofil.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/canaux/newCanal.dart';
import 'package:afrotok/pages/tiktokProjet/tiktokPages.dart';
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
import '../../challenge/challengeDashbord.dart';
import '../../tiktokProjet/userTiktokVide.dart';
import '../../userPosts/favorites_posts.dart';
import '../userAbonnementPage.dart';
import 'adminprofil.dart';

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
      return "${(number / 1000).toStringAsFixed(1)}k";
    } else if (number < 1000000000) {
      return "${(number / 1000000).toStringAsFixed(1)}M";
    } else {
      return "${(number / 1000000000).toStringAsFixed(1)}B";
    }
  }

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;

    // Définition des couleurs du thème
    const Color primaryBlack = Color(0xFF121212);
    const Color primaryRed = Color(0xFFE53935);
    const Color primaryYellow = Color(0xFFFFD600);
    const Color secondaryBlack = Color(0xFF1E1E1E);
    const Color accentRed = Color(0xFFFF5252);
    const Color lightYellow = Color(0xFFFFF176);
    const Color textWhite = Color(0xFFF5F5F5);
    const Color textGrey = Color(0xFF9E9E9E);

    return Scaffold(
      backgroundColor: primaryBlack,
      appBar: AppBar(
        backgroundColor: primaryBlack,
        elevation: 0,
        title: Text(
          "Mon Profile",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: textWhite,
            letterSpacing: 1.0,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: secondaryBlack,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Logo(),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section Header avec informations utilisateur
              GestureDetector(
                onTap: () {
                  Navigator.pushNamed(context, '/profil_detail_user');

                },
                child: Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: secondaryBlack,
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
                      // Avatar avec bordure décorative
                      Stack(
                        children: [
                          Container(
                            padding: EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [primaryRed, primaryYellow],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: CircleAvatar(
                              radius: 40,
                              backgroundImage: NetworkImage(
                                  '${authProvider.loginUserData!.imageUrl!}'),
                              backgroundColor: secondaryBlack,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: primaryBlack,
                                shape: BoxShape.circle,
                                border: Border.all(color: primaryYellow, width: 2),
                              ),
                              child: Icon(
                                Icons.edit,
                                size: 16,
                                color: primaryYellow,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(width: 20),

                      // Informations utilisateur
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "@${authProvider.loginUserData!.pseudo}",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: textWhite,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 8),

                            // Statistiques
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  children: [
                                    Text(
                                      "${formatNumber(authProvider.loginUserData!.userAbonnesIds!.length ?? 0)}",
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: primaryYellow,
                                      ),
                                    ),
                                    Text(
                                      "Abonnés",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: textGrey,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  height: 30,
                                  width: 1,
                                  color: Colors.grey[700],
                                ),
                                Column(
                                  children: [
                                    Text(
                                      "${formatNumber(authProvider.loginUserData!.userlikes!)}",
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: primaryRed,
                                      ),
                                    ),
                                    Text(
                                      "Likes",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: textGrey,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 20),

              // Section "Mes Looks"
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OtherUserPage(otherUser:authProvider.loginUserData!),
                    ),
                  );
                },
                child: Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: secondaryBlack,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.style,
                            color: primaryYellow,
                            size: 24,
                          ),
                          SizedBox(width: 10),
                          Text(
                            "Mes Looks",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: textWhite,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 10),

              // Menu d'options
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: secondaryBlack,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Ligne 1
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMenuButton(
                          icon: Icons.person,
                          label: "Mes Infos",
                          color: Colors.blue,
                          onTap: () {
                            Navigator.pushNamed(context, '/profil_detail_user');
                          },
                        ),
                        _buildMenuButton(
                          icon: Icons.store,
                          label: "Entreprise",
                          color: Color(0xFF2ECC71),
                          onTap: () async {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => Scaffold(
                                  backgroundColor: Colors.white,
                                  body: Center(
                                    child: CircularProgressIndicator(color: Color(0xFF2ECC71)),
                                  ),
                                ),
                              ),
                            );

                            try {
                              final value = await userProvider.getUserEntreprise(authProvider.loginUserData.id!);
                              Navigator.pop(context);

                              if (value) {
                                Navigator.pushNamed(context, '/profile_entreprise');
                              } else {
                                showDialog(
                                  context: context,
                                  builder: (_) => Dialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Container(
                                      padding: EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: secondaryBlack,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CircleAvatar(
                                            radius: 30,
                                            backgroundColor: Color(0xFF2ECC71).withOpacity(0.1),
                                            child: Icon(Icons.store, color: Color(0xFF2ECC71), size: 32),
                                          ),
                                          SizedBox(height: 12),
                                          Text(
                                            "Créez votre entreprise",
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: textWhite,
                                            ),
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            "Vendez vos produits et services avec une entreprise unique.",
                                            textAlign: TextAlign.center,
                                            style: TextStyle(fontSize: 14, color: textGrey),
                                          ),
                                          SizedBox(height: 20),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Color(0xFF2ECC71),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                                            ),
                                            onPressed: () {
                                              Navigator.pop(context);
                                              Navigator.pushNamed(context, '/new_entreprise');
                                            },
                                            child: Text("Créer maintenant", style: TextStyle(color: Colors.white)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Erreur lors du chargement"),
                                  backgroundColor: primaryRed,
                                ),
                              );
                            }
                          },
                        ),
                        _buildMenuButton(
                          icon: Icons.monetization_on,
                          label: "Monétisation",
                          color: Colors.green,
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => MonetisationPage()));
                          },
                        ),
                      ],
                    ),

                    SizedBox(height: 15),

                    // Ligne 2
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMenuButton(
                          icon: Icons.card_membership,
                          label: "Abonnement",
                          color: Colors.blue,
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => AbonnementScreen()));
                          },
                        ),
                        _buildMenuButton(
                          icon: Icons.bookmark_border,
                          label: "Favoris",
                          color: primaryYellow,
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => FavoritePostsPage()));
                          },
                        ),
                        _buildMenuButton(
                          icon: FontAwesome.forumbee,
                          label: "Canaux",
                          color: Colors.green,
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => CanalListPageByUser()));
                          },
                        ),
                      ],
                    ),

                    SizedBox(height: 15),

                    // Options admin (si applicable)
                    if (authProvider.loginUserData.role == UserRole.ADM.name) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMenuButton(
                            icon: Icons.build_circle,
                            label: "AppData",
                            color: Colors.blue,
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => AppInfoPage()));
                            },
                          ),
                          _buildMenuButton(
                            icon: Icons.emoji_events,
                            label: "Challenge",
                            color: primaryYellow,
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => ChallengeDashboardPage()));
                            },
                          ),
                          _buildMenuButton(
                            icon: Icons.business,
                            label: "Contacts",
                            color: Colors.purple,
                            onTap: () {
                              Navigator.pushNamed(context, '/list_conversation_user_entreprise');
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: 15),
                    ],

                    // Bouton déconnexion
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            primaryRed.withOpacity(0.1),
                            primaryRed.withOpacity(0.05)
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: primaryRed.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: TextButton.icon(
                        onPressed: () {
                          // Action de déconnexion
                        },
                        icon: Icon(
                          Icons.exit_to_app,
                          color: primaryRed,
                        ),
                        label: Text(
                          "Déconnexion",
                          style: TextStyle(
                            color: primaryRed,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: Colors.grey[800]!,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 5,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: color.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: Color(0xFFF5F5F5),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
// class UserProfil extends StatefulWidget {
//   const UserProfil({super.key});
//
//   @override
//   State<UserProfil> createState() => _UserProfilState();
// }
//
// class _UserProfilState extends State<UserProfil> {
//
//   late UserAuthProvider authProvider =
//   Provider.of<UserAuthProvider>(context, listen: false);
//   late UserProvider userProvider =
//   Provider.of<UserProvider>(context, listen: false);
//
//   late PostProvider postProvider =
//   Provider.of<PostProvider>(context, listen: false);
//   String formatNumber(int number) {
//     if (number < 1000) {
//       return number.toString();
//     } else if (number < 1000000) {
//       return "${number / 1000} k";
//     } else if (number < 1000000000) {
//       return "${number / 1000000} m";
//     } else {
//       return "${number / 1000000000} b";
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     double height = MediaQuery.of(context).size.height;
//     double width = MediaQuery.of(context).size.width;
//     return Scaffold(
//       backgroundColor: ConstColors.backgroundColor,
//       appBar: AppBar(
//         title: TextCustomerPageTitle(
//           titre: "Mon Profile",
//           fontSize: SizeText.homeProfileTextSize,
//           couleur: ConstColors.textColors,
//           fontWeight: FontWeight.bold,
//         ),
//
//         actions: [
//           Padding(
//             padding: const EdgeInsets.only(right: 8.0),
//             child: Logo(),
//           )
//         ],
//         //title: Text(widget.title),
//       ),
//       body: SingleChildScrollView(
//         scrollDirection: Axis.vertical,
//         child: Container(
//           height: height*1.28,
//
//           child: Padding(
//             padding: const EdgeInsets.all(8.0),
//             child: Column(
//               mainAxisSize: MainAxisSize.max,
//               children: [
//                 Padding(
//                   padding: const EdgeInsets.only(bottom: 8.0),
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       Row(
//                         children: [
//                           Padding(
//                             padding: const EdgeInsets.only(right: 15.0),
//                             child: CircleAvatar(
//                               radius: 30,
//                               backgroundImage: NetworkImage(
//                                   '${authProvider.loginUserData!.imageUrl!}'),
//                             ),
//                           ),
//                           SizedBox(
//                             height: 2,
//                           ),
//                           Row(
//                             children: [
//                               Column(
//                                 mainAxisAlignment: MainAxisAlignment.start,
//                                 crossAxisAlignment:CrossAxisAlignment.start ,
//                                 children: [
//                                   SizedBox(
//                                     //width: 100,
//                                     child: TextCustomerUserTitle(
//                                       titre: "@${authProvider.loginUserData!.pseudo}",
//                                       fontSize: SizeText.homeProfileTextSize,
//                                       couleur: ConstColors.textColors,
//                                       fontWeight: FontWeight.bold,
//                                     ),
//                                   ),
//                                   TextCustomerUserTitle(
//                                     titre: "${formatNumber(authProvider.loginUserData!.userAbonnesIds!.length??0)} abonné(s)",
//                                     fontSize: SizeText.homeProfileTextSize,
//                                     couleur: ConstColors.textColors,
//                                     fontWeight: FontWeight.w400,
//                                   ),
//                                   TextCustomerUserTitle(
//                                     titre:
//                                     "${formatNumber(authProvider.loginUserData!.userlikes!)} like(s)",
//                                     fontSize: SizeText.homeProfileTextSize,
//                                     couleur: Colors.green,
//                                     fontWeight: FontWeight.w700,
//                                   ),
//
//                                 ],
//                               ),
//
//                             ],
//                           ),
//                         ],
//                       ),
//                       /*
//                       Padding(
//                         padding: const EdgeInsets.only(right: 12.0),
//                         child: Column(
//                           children: [
//                             SizedBox(
//                               //width: 100,
//                               child: TextCustomerUserTitle(
//                                 titre: "PubliCach",
//                                 fontSize: SizeText.homeProfileTextSize,
//                                 couleur: ConstColors.textColors,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                             TextCustomerUserTitle(
//                               titre: "500",
//                               fontSize: SizeText.homeProfileTextSize,
//                               couleur: ConstColors.textColors,
//                               fontWeight: FontWeight.w400,
//                             ),
//                             SizedBox(height: 2,),
//                             AchatPubliCachButton(),
//
//                           ],
//                         ),
//                       ),
//
//                        */
//                     ],
//                   ),
//                 ),
//                 SizedBox(
//                   height: 10,
//
//                 ),
//
//                 // Row(
//                 //   mainAxisAlignment: MainAxisAlignment.spaceAround,
//                 //   children: [
//                 //     Column(
//                 //       children: [
//                 //         Container(
//                 //           child: TextCustomerUserTitle(
//                 //             titre: "${authProvider.loginUserData!.mesPubs}",
//                 //             fontSize: SizeText.homeProfileTextSize,
//                 //             couleur: ConstColors.textColors,
//                 //             fontWeight: FontWeight.w600,
//                 //           ),
//                 //         ),
//                 //         Container(
//                 //           child: TextCustomerUserTitle(
//                 //             titre: "Mes Publications ",
//                 //             fontSize: SizeText.homeProfileTextSize,
//                 //             couleur: ConstColors.textColors,
//                 //             fontWeight: FontWeight.w500,
//                 //           ),
//                 //         ),
//                 //       ],
//                 //     ),
//                 //     Column(
//                 //       children: [
//                 //         Container(
//                 //           child: TextCustomerUserTitle(
//                 //             titre: "${authProvider.loginUserData!.pubEntreprise}",
//                 //             fontSize: SizeText.homeProfileTextSize,
//                 //             couleur: ConstColors.textColors,
//                 //             fontWeight: FontWeight.w600,
//                 //           ),
//                 //         ),
//                 //         Container(
//                 //           child: TextCustomerUserTitle(
//                 //             titre: "Publications Entreprises ",
//                 //             fontSize: SizeText.homeProfileTextSize,
//                 //             couleur: ConstColors.textColors,
//                 //             fontWeight: FontWeight.w500,
//                 //           ),
//                 //         ),
//                 //       ],
//                 //     ),
//                 //   ],
//                 // ),
//                 // SizedBox(
//                 //   height: 30,
//                 //
//                 // ),
//                 Padding(
//                   padding: const EdgeInsets.all(8.0),
//                   child: Row(
//                    // mainAxisAlignment: MainAxisAlignment.spaceAround,
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Expanded(
//                         flex: 2,
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             GestureDetector(
//                               onTap: () {
//                                 Navigator.pushNamed(context, '/profil_detail_user');
//                               },
//                               child: ClipRRect(
//                                 borderRadius: BorderRadius.only(topRight: Radius.circular(50),bottomRight: Radius.circular(50)),
//                                 child: Container(
//                                   color: ConstColors.buttonsColors,
//                                   // alignment: Alignment.centerLeft,
//                                   width: 180,
//                                   child: Padding(
//                                     padding: const EdgeInsets.all(8.0),
//                                     child: Row(
//                                       children: [
//                                         Padding(
//                                           padding: const EdgeInsets.only(right: 5.0),
//                                           child: Container(
//                                             child: Image.asset(
//                                               'assets/icon/info.png',
//                                               height: 20,
//                                               width: 20,
//                                             ),
//                                           ),
//                                         ),
//                                         Container(
//                                           child: TextCustomerMenu(
//                                             titre: "Mes Informations",
//                                             fontSize: SizeText.homeProfileTextSize,
//                                             couleur: ConstColors.textColors,
//                                             fontWeight: FontWeight.w600,
//                                           ),
//                                         )
//                                       ],
//
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                             ),
//                             SizedBox(height: 10,),
//                             GestureDetector(
//                               onTap: () async {
//                                   // Affiche une page de chargement temporaire
//                                   Navigator.push(
//                                     context,
//                                     MaterialPageRoute(
//                                       builder: (_) => Scaffold(
//                                         backgroundColor: Colors.white,
//                                         body: Center(
//                                           child: CircularProgressIndicator(color: Color(0xFF2ECC71)),
//                                         ),
//                                       ),
//                                     ),
//                                   );
//
//                                   try {
//                                     final value = await userProvider.getUserEntreprise(authProvider.loginUserData.id!);
//
//                                     // Ferme la page de chargement
//                                     Navigator.pop(context);
//
//                                     if (value) {
//                                       Navigator.pushNamed(context, '/profile_entreprise');
//                                     } else {
//                                       // Affiche un modal si pas d’entreprise
//                                       showDialog(
//                                         context: context,
//                                         builder: (_) => Dialog(
//                                           shape: RoundedRectangleBorder(
//                                             borderRadius: BorderRadius.circular(16),
//                                           ),
//                                           child: Padding(
//                                             padding: const EdgeInsets.all(20),
//                                             child: Column(
//                                               mainAxisSize: MainAxisSize.min,
//                                               children: [
//                                                 CircleAvatar(
//                                                   radius: 30,
//                                                   backgroundColor: Color(0xFF2ECC71).withOpacity(0.1),
//                                                   child: Icon(Icons.store_mall_directory, color: Color(0xFF2ECC71), size: 32),
//                                                 ),
//                                                 SizedBox(height: 12),
//                                                 Text(
//                                                   "Créez votre entreprise",
//                                                   style: TextStyle(
//                                                     fontSize: 16,
//                                                     fontWeight: FontWeight.bold,
//                                                     color: Colors.black87,
//                                                   ),
//                                                 ),
//                                                 SizedBox(height: 8),
//                                                 Text(
//                                                   "Pour vendre vos produits et services, créez gratuitement une entreprise avec un nom unique.",
//                                                   textAlign: TextAlign.center,
//                                                   style: TextStyle(fontSize: 13, color: Colors.black54),
//                                                 ),
//                                                 SizedBox(height: 20),
//                                                 ElevatedButton(
//                                                   style: ElevatedButton.styleFrom(
//                                                     backgroundColor: Color(0xFF2ECC71),
//                                                     shape: RoundedRectangleBorder(
//                                                       borderRadius: BorderRadius.circular(8),
//                                                     ),
//                                                     padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
//                                                   ),
//                                                   onPressed: () {
//                                                     Navigator.pop(context); // ferme le modal
//                                                     Navigator.pushNamed(context, '/new_entreprise');
//                                                   },
//                                                   child: Text("Créer maintenant", style: TextStyle(color: Colors.white)),
//                                                 ),
//                                               ],
//                                             ),
//                                           ),
//                                         ),
//                                       );
//                                     }
//                                   } catch (e) {
//                                     Navigator.pop(context); // Ferme le loader si erreur
//                                     ScaffoldMessenger.of(context).showSnackBar(
//                                       SnackBar(content: Text("Erreur lors du chargement")),
//                                     );
//                                   }
//
//                               },
//                               child: Row(
//                                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                 children: [
//                                   ClipRRect(
//                                     borderRadius: BorderRadius.only(topRight: Radius.circular(50),bottomRight: Radius.circular(50)),
//                                     child: Container(
//                                       color: ConstColors.buttonsColors,
//                                       // alignment: Alignment.centerLeft,
//                                       width: 180,
//                                       child: Padding(
//                                         padding: const EdgeInsets.all(8.0),
//                                         child: Row(
//                                           children: [
//                                             Padding(
//                                               padding: const EdgeInsets.only(right: 5.0),
//                                               child: Container(
//                                                 child: Image.asset(
//                                                   'assets/icon/entreprise.png',
//                                                   height: 20,
//                                                   width: 20,
//                                                 ),
//                                               ),
//                                             ),
//                                           Container(
//                                                 child: TextCustomerMenu(
//                                                   titre: "Mon Entreprise",
//                                                   fontSize: SizeText.homeProfileTextSize,
//                                                   couleur: ConstColors.textColors,
//                                                   fontWeight: FontWeight.w600,
//                                                 ),
//                                               ),
//
//                                           ],
//
//                                         ),
//                                       ),
//                                     ),
//                                   ),
//
//
//                                   // GestureDetector(
//                                   //   onTap: () {
//                                   //
//                                   //           Navigator.pushNamed(context, '/new_entreprise');
//                                   //
//                                   //
//                                   //   },
//                                   //   child:authProvider.loginUserData!.hasEntreprise!?Container(): Container(
//                                   //     child: TextCustomerMenu(
//                                   //       titre: "Creer",
//                                   //       fontSize: SizeText.homeProfileTextSize,
//                                   //       couleur: Colors.red,
//                                   //       fontWeight: FontWeight.w600,
//                                   //     ),
//                                   //   ),
//                                   // )
//                                 ],
//                               ),
//                             ),
//                             SizedBox(height: 10,),
//                             GestureDetector(
//                               onTap: () {
//                                 Navigator.push(context, MaterialPageRoute(builder: (context) => MonetisationPage(),));
//                               },
//                               child: ClipRRect(
//                                 borderRadius: BorderRadius.only(topRight: Radius.circular(50),bottomRight: Radius.circular(50)),
//                                 child: Container(
//                                   color: ConstColors.buttonsColors,
//                                   // alignment: Alignment.centerLeft,
//                                   width: 180,
//                                   child: Padding(
//                                     padding: const EdgeInsets.all(8.0),
//                                     child: Row(
//                                       children: [
//                                         Padding(
//                                           padding: const EdgeInsets.only(right: 5.0),
//                                           child: Container(
//                                             child: Image.asset(
//                                               'assets/icon/monetization.png',
//                                               height: 20,
//                                               width: 20,
//                                             ),
//                                           ),
//                                         ),
//                                         Container(
//                                           child: TextCustomerMenu(
//                                             titre: "Monétisation",
//                                             fontSize: SizeText.homeProfileTextSize,
//                                             couleur: ConstColors.textColors,
//                                             fontWeight: FontWeight.w600,
//                                           ),
//                                         )
//                                       ],
//
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                             ),
//                             SizedBox(height: 10,),
//                             GestureDetector(
//                               onTap: () {
//                                 Navigator.push(context, MaterialPageRoute(builder: (context) => AbonnementScreen(),));
//                               },
//                               child: ClipRRect(
//                                 borderRadius: BorderRadius.only(topRight: Radius.circular(50),bottomRight: Radius.circular(50)),
//                                 child: Container(
//                                   color: ConstColors.buttonsColors,
//                                   // alignment: Alignment.centerLeft,
//                                   width: 180,
//                                   child: Padding(
//                                     padding: const EdgeInsets.all(8.0),
//                                     child: Row(
//                                       children: [
//                                         Padding(
//                                           padding: const EdgeInsets.only(right: 5.0),
//                                           child: Container(
//                                             child: Icon(Icons.card_membership,color: Colors.blue,size: 20,),
//                                           ),
//                                         ),
//                                         Container(
//                                           child: TextCustomerMenu(
//                                             titre: "Abonnement",
//                                             fontSize: SizeText.homeProfileTextSize,
//                                             couleur: ConstColors.textColors,
//                                             fontWeight: FontWeight.w600,
//                                           ),
//                                         )
//                                       ],
//
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                             ),
//                             if(authProvider.loginUserData.role==UserRole.ADM.name)
//                             SizedBox(height: 10,),
//                             if(authProvider.loginUserData.role==UserRole.ADM.name)
//                             GestureDetector(
//                               onTap: () {
//                                 Navigator.push(context, MaterialPageRoute(builder: (context) => AppInfoPage(),));
//                               },
//                               child: ClipRRect(
//                                 borderRadius: BorderRadius.only(topRight: Radius.circular(50),bottomRight: Radius.circular(50)),
//                                 child: Container(
//                                   color: ConstColors.buttonsColors,
//                                   // alignment: Alignment.centerLeft,
//                                   width: 180,
//                                   child: Padding(
//                                     padding: const EdgeInsets.all(8.0),
//                                     child: Row(
//                                       children: [
//                                         Padding(
//                                           padding: const EdgeInsets.only(right: 5.0),
//                                           child: Container(
//                                             child: Icon(Icons.build_circle,color: Colors.blue,),
//                                           ),
//                                         ),
//                                         Container(
//                                           child: TextCustomerMenu(
//                                             titre: "AppData",
//                                             fontSize: SizeText.homeProfileTextSize,
//                                             couleur: ConstColors.textColors,
//                                             fontWeight: FontWeight.w600,
//                                           ),
//                                         )
//                                       ],
//
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                             ),
//                             if(authProvider.loginUserData.role==UserRole.ADM.name)
//                               SizedBox(height: 10,),
//                             if (authProvider.loginUserData.role == UserRole.ADM.name)
//                               GestureDetector(
//                                 onTap: () {
//                                   Navigator.push(context, MaterialPageRoute(builder: (context) => ChallengeDashboardPage(),));
//                                 },
//                                 child: ClipRRect(
//                                   borderRadius: BorderRadius.only(topRight: Radius.circular(50),bottomRight: Radius.circular(50)),
//                                   child: Container(
//                                     color: ConstColors.buttonsColors,
//                                     // alignment: Alignment.centerLeft,
//                                     width: 180,
//                                     child: Padding(
//                                       padding: const EdgeInsets.all(8.0),
//                                       child: Row(
//                                         children: [
//                                           Padding(
//                                             padding: const EdgeInsets.only(right: 5.0),
//                                             child: Container(
//                                               child: Icon(Icons.emoji_events,color: Colors.yellow,),
//                                             ),
//                                           ),
//                                           Container(
//                                             child: TextCustomerMenu(
//                                               titre: "Challenge Accuiel",
//                                               fontSize: SizeText.homeProfileTextSize,
//                                               couleur: ConstColors.textColors,
//                                               fontWeight: FontWeight.w600,
//                                             ),
//                                           )
//                                         ],
//
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//                               ),
//
//                             // SizedBox(height: 10,),
//                             // GestureDetector(
//                             //   onTap: () {
//                             //     Navigator.push(context, MaterialPageRoute(builder: (context) => UserVideoFeedTiktokPage(),));
//                             //   },
//                             //   child: ClipRRect(
//                             //     borderRadius: BorderRadius.only(topRight: Radius.circular(50),bottomRight: Radius.circular(50)),
//                             //     child: Container(
//                             //       color: ConstColors.buttonsColors,
//                             //       // alignment: Alignment.centerLeft,
//                             //       width: 180,
//                             //       child: Padding(
//                             //         padding: const EdgeInsets.all(8.0),
//                             //         child: Row(
//                             //           children: [
//                             //             Padding(
//                             //               padding: const EdgeInsets.only(right: 5.0),
//                             //               child: Container(
//                             //                 child: Icon(Icons.tiktok,color: Colors.red,),
//                             //               ),
//                             //             ),
//                             //             Container(
//                             //               child: TextCustomerMenu(
//                             //                 titre: "Mon Tiktok",
//                             //                 fontSize: SizeText.homeProfileTextSize,
//                             //                 couleur: ConstColors.textColors,
//                             //                 fontWeight: FontWeight.w600,
//                             //               ),
//                             //             )
//                             //           ],
//                             //
//                             //         ),
//                             //       ),
//                             //     ),
//                             //   ),
//                             // ),
//                             SizedBox(height: 10,),
//                             GestureDetector(
//                               onTap: () {
//                                 Navigator.push(context, MaterialPageRoute(builder: (context) => FavoritePostsPage(),));
//                               },
//                               child: ClipRRect(
//                                 borderRadius: BorderRadius.only(topRight: Radius.circular(50),bottomRight: Radius.circular(50)),
//                                 child: Container(
//                                   color: ConstColors.buttonsColors,
//                                   // alignment: Alignment.centerLeft,
//                                   width: 180,
//                                   child: Padding(
//                                     padding: const EdgeInsets.all(8.0),
//                                     child: Row(
//                                       children: [
//                                         Padding(
//                                           padding: const EdgeInsets.only(right: 5.0),
//                                           child: Container(
//                                             child: Icon(Icons.bookmark_border,size: 20,color: Colors.yellow,),
//                                           ),
//                                         ),
//                                         Container(
//                                           child: TextCustomerMenu(
//                                             titre: "Mes Favoris",
//                                             fontSize: SizeText.homeProfileTextSize,
//                                             couleur: ConstColors.textColors,
//                                             fontWeight: FontWeight.w600,
//                                           ),
//                                         )
//                                       ],
//
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                             ),
//                             SizedBox(height: 10,),
//                             GestureDetector(
//                               onTap: () {
//                                 Navigator.push(context, MaterialPageRoute(builder: (context) => CanalListPageByUser(),));
//                               },
//                               child: ClipRRect(
//                                 borderRadius: BorderRadius.only(topRight: Radius.circular(50),bottomRight: Radius.circular(50)),
//                                 child: Container(
//                                   color: ConstColors.buttonsColors,
//                                   // alignment: Alignment.centerLeft,
//                                   width: 180,
//                                   child: Padding(
//                                     padding: const EdgeInsets.all(8.0),
//                                     child: Row(
//                                       children: [
//                                         Padding(
//                                           padding: const EdgeInsets.only(right: 5.0),
//                                           child: Container(
//                                             child: Icon(FontAwesome.forumbee,size: 20,color: Colors.green,),
//                                           ),
//                                         ),
//                                         Container(
//                                           child: TextCustomerMenu(
//                                             titre: "Mes Canaux",
//                                             fontSize: SizeText.homeProfileTextSize,
//                                             couleur: ConstColors.textColors,
//                                             fontWeight: FontWeight.w600,
//                                           ),
//                                         )
//                                       ],
//
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                             ),
//                             // SizedBox(height: 10,),
//                             // GestureDetector(
//                             //   onTap: () {
//                             //     Navigator.push(context, MaterialPageRoute(builder: (context) => PostsMonetiserPage(title: '',),));
//                             //   },
//                             //   child: ClipRRect(
//                             //     borderRadius: BorderRadius.only(topRight: Radius.circular(50),bottomRight: Radius.circular(50)),
//                             //     child: Container(
//                             //       color: ConstColors.buttonsColors,
//                             //       // alignment: Alignment.centerLeft,
//                             //       width: 180,
//                             //       child: Padding(
//                             //         padding: const EdgeInsets.all(8.0),
//                             //         child: Row(
//                             //           children: [
//                             //             Padding(
//                             //               padding: const EdgeInsets.only(right: 5.0),
//                             //               child: Container(
//                             //                 child: Icon(FontAwesome.money,size: 20,color: Colors.green,),
//                             //               ),
//                             //             ),
//                             //             Container(
//                             //               child: TextCustomerMenu(
//                             //                 titre: "Posts Monetiser",
//                             //                 fontSize: SizeText.homeProfileTextSize,
//                             //                 couleur: ConstColors.textColors,
//                             //                 fontWeight: FontWeight.w600,
//                             //               ),
//                             //             )
//                             //           ],
//                             //
//                             //         ),
//                             //       ),
//                             //     ),
//                             //   ),
//                             // ),
//                             SizedBox(height: 10,),
//                             ClipRRect(
//                               borderRadius: BorderRadius.only(topRight: Radius.circular(50),bottomRight: Radius.circular(50)),
//                               child: Container(
//                                 color: ConstColors.buttonsColors,
//                                 // alignment: Alignment.centerLeft,
//                                 width: 180,
//                                 child: Padding(
//                                   padding: const EdgeInsets.all(8.0),
//                                   child: Row(
//                                     children: [
//                                       Padding(
//                                         padding: const EdgeInsets.only(right: 5.0),
//                                         child: Container(
//                                           child: Image.asset(
//                                             'assets/icon/entrepriseContact.png',
//                                             height: 20,
//                                             width: 20,
//                                           ),
//                                         ),
//                                       ),
//                                       GestureDetector(
//                                         onTap: () {
//                                           Navigator.pushNamed(context, '/list_conversation_user_entreprise');
//                                         },
//                                         child: Container(
//                                           child: TextCustomerMenu(
//                                             titre: "Entreprise Contacté",
//                                             fontSize: SizeText.homeProfileTextSize,
//                                             couleur: ConstColors.textColors,
//                                             fontWeight: FontWeight.w600,
//                                           ),
//                                         ),
//                                       )
//                                     ],
//
//                                   ),
//                                 ),
//                               ),
//                             ),
//
//                           ],
//                         ),
//                       ),
//
//                     ],
//                   ),
//                 ),
//                 SizedBox(
//                   height: 10,
//
//                 ),
//                     Flexible(
//
//                       child: SizedBox(
//                         //width: width,
//                         //height:height*0.86 ,
//                         child: ContainedTabBarView(
//                           tabs: [
//                         Container(
//                         child: TextCustomerMenu(
//                         titre: "Mes Postes",
//                           fontSize: SizeText.homeProfileTextSize,
//                           couleur: ConstColors.textColors,
//                           fontWeight: FontWeight.w600,
//                         ),
//                         ),
//                             Container(
//                         child: TextCustomerMenu(
//                           titre: "Pubs Entreprises",
//                           fontSize: SizeText.homeProfileTextSize,
//                           couleur: ConstColors.textColors,
//                           fontWeight: FontWeight.w600,
//                         ),
//                             ),
//                           ],
//                           tabBarProperties: TabBarProperties(
//                             height: 32.0,
//                             indicatorColor: ConstColors.menuItemsColors,
//                             indicatorWeight: 6.0,
//                             labelColor: Colors.black,
//                             unselectedLabelColor: Colors.grey[400],
//                           ),
//                           views: [
//                             Padding(
//                               padding: const EdgeInsets.only(top: 8.0),
//                               child: UserPublicationView(),
//                             ),
//                             Padding(
//                                 padding: const EdgeInsets.only(top: 8.0),
//                                 child: EntreprisePublicationView()),
//                           ],
//                           onChange: (index) => print(index),
//                         ),
//                       ),
//                     ),
//
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
