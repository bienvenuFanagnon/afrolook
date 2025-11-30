import 'package:afrotok/pages/LiveAgora/live_list_page.dart';
import 'package:afrotok/pages/afroshop/marketPlace/acceuil/home_afroshop.dart';
import 'package:afrotok/pages/challenge/challengeDetails.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constant/custom_theme.dart';
import '../../models/model_data.dart';
import '../../providers/afroshop/categorie_produits_provider.dart';
import '../../providers/userProvider.dart';
import '../LiveAgora/create_live_page.dart';
import '../LiveAgora/livePage.dart';
import '../LiveAgora/livesAgora.dart';
import '../afroshop/marketPlace/acceuil/produit_details.dart';
import '../afroshop/marketPlace/component.dart';
import '../classements/userClassement.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/models/model_data.dart';

import '../info.dart';
class TopFiveModal {
  static Future<void> showTopFiveModal(
      BuildContext context, List<UserData> topUsers) async {
    final prefs = await SharedPreferences.getInstance();
    final lastShownDate = prefs.getString('lastShownTopFiveDate');
    final currentDate = DateTime.now().toString().substring(0, 10);

    await prefs.setString('lastShownTopFiveDate', currentDate);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.yellow[700]!, width: 2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // En-tête avec croix
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green[800]!.withOpacity(0.7),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Column(
                              children: [
                                Text(
                                  "TOP 5 Afrolook Stars",
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.yellow[700],
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  "Découvrez les stars du jour!",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: GestureDetector(
                              onTap: () => Navigator.of(context).pop(),
                              child: Icon(
                                Icons.close,
                                color: Colors.yellow[700],
                                size: 28,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Liste des utilisateurs
                    Flexible(
                      child: ListView.builder(
                        itemCount: topUsers.length,
                        shrinkWrap: true,
                        physics: BouncingScrollPhysics(),
                        padding: EdgeInsets.symmetric(vertical: 8),
                        itemBuilder: (context, index) {
                          return TopFiveUserItem(
                            user: topUsers[index],
                            rank: index + 1,
                          );
                        },
                      ),
                    ),

                    // Bouton d'action
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green[800]!.withOpacity(0.3),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => UserClassement(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.yellow[700],
                          foregroundColor: Colors.black,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          "Voir le classement complet",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

}

class TopFiveUserItem extends StatelessWidget {
  final UserData user;
  final int rank;

  const TopFiveUserItem({
    required this.user,
    required this.rank,
  });

  @override
  Widget build(BuildContext context) {
    Color rankColor;
    IconData rankIcon;

    if (rank == 1) {
      rankColor = Colors.yellow[700]!;
      rankIcon = Icons.emoji_events;
    } else if (rank == 2) {
      rankColor = Colors.grey[400]!;
      rankIcon = Icons.workspace_premium;
    } else if (rank == 3) {
      rankColor = Colors.orange[800]!;
      rankIcon = Icons.workspace_premium;
    } else {
      rankColor = Colors.green[600]!;
      rankIcon = Icons.star;
    }

    return Container(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // RANK ICON
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: rankColor,
              shape: BoxShape.circle,
            ),
            child: rank <= 3
                ? Icon(rankIcon, color: Colors.black, size: 24)
                : Text(
              "$rank",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),

          SizedBox(width: 12),

          // PROFILE + BADGE VERIFIE
          Stack(
            children: [
              CircleAvatar(
                backgroundImage: NetworkImage(user.imageUrl ?? ''),
                radius: 24,
                backgroundColor: Colors.grey[800],
              ),
              if (user.isVerify ?? false)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.verified,
                      color: Colors.green,
                      size: 16,
                    ),
                  ),
                ),
            ],
          ),

          SizedBox(width: 12),

          // NAME + FOLLOWERS + POPULARITY
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // PSEUDO
                Text(
                  "@${user.pseudo}",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),

                SizedBox(height: 4),

                // FOLLOWERS
                Row(
                  children: [
                    Icon(Icons.people, size: 14, color: Colors.green[600]),
                    SizedBox(width: 4),
                    Text(
                      "${user.userAbonnesIds?.length ?? 0} abonnés",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 2),

                // ⭐ POPULARITÉ
                Row(
                  children: [
                    Icon(Icons.star, size: 12, color: Colors.yellow[700]),
                    SizedBox(width: 4),
                    Text(
                      "${(user.popularite ?? 0).toStringAsFixed(2)}%",
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // RANK ON RIGHT SIDE
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: rankColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: rankColor, width: 1),
            ),
            child: Text(
              "#$rank",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: rankColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}





class TopLiveGridModal {
  static Future<void> showTopLiveGridModal(BuildContext context) async {
    final liveProvider = context.read<LiveProvider>();
    final authProvider = context.read<UserAuthProvider>();

    // Charger les lives les plus populaires
    await liveProvider.fetchActiveLives();

    // Filtrer et trier les lives actifs avec le plus de viewers
    final activeLives = liveProvider.activeLives.where((live) => live.isLive).toList();
    activeLives.sort((a, b) => b.viewerCount.compareTo(a.viewerCount));
    final displayedLives = activeLives.take(5).toList();
    final hasActiveLive = displayedLives.isNotEmpty;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(maxWidth: 500),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Color(0xFFF9A825), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.yellow.withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // En-tête avec titre accrocheur
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFF9A825), Colors.red],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Column(
                          children: [
                            Text(
                              "🔥 LIVE POPULAIRES 🔥",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              "Rejoignez l'expérience en direct!",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Icon(
                            Icons.close,
                            color: Colors.black,
                            size: 28,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Contenu principal
                if (hasActiveLive)
                  _buildLiveGrid(context, displayedLives, authProvider)
                else
                  _buildNoLiveContent(context),

                // Pied de page avec incitation
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        "En faisant un live, vous pouvez gagner plus de 50 000 FCFA!",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFF9A825),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Partagez vos talents avec la communauté Afrolook",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                      SizedBox(height: 12),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => LiveListPage(),));

                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.live_tv, color: Colors.red, size: 16),
                            SizedBox(width: 4),
                            Text(
                              "Voir plus de lives",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _buildLiveGrid(BuildContext context, List<PostLive> lives, UserAuthProvider authProvider) {
    return Container(
      padding: EdgeInsets.all(16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.85,
        ),
        itemCount: lives.length,
        itemBuilder: (context, index) {
          return _LiveGridItem(
            live: lives[index],
            rank: index + 1,
            authProvider: authProvider,
          );
        },
      ),
    );
  }

  static Widget _buildNoLiveContent(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.videocam_off,
            size: 64,
            color: Colors.red,
          ),
          SizedBox(height: 16),
          Text(
            "Aucun live en cours!",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 12),
          Text(
            "Soyez le premier à lancer un live et attirez l'attention de la communauté!",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[400],
            ),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Naviguer vers la page de création de live
              Navigator.push(context, MaterialPageRoute(builder: (context) => CreateLivePage()));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              "CRÉER UN LIVE MAINTENANT",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(height: 12),
          Text(
            "Invitez vos abonnés à participer!",
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveGridItem extends StatelessWidget {
  final PostLive live;
  final int rank;
  final UserAuthProvider authProvider;

  const _LiveGridItem({
    required this.live,
    required this.rank,
    required this.authProvider,
  });

  @override
  Widget build(BuildContext context) {
    Color rankColor;

    if (rank == 1) {
      rankColor = Color(0xFFFFD700); // Or
    } else if (rank == 2) {
      rankColor = Color(0xFFC0C0C0); // Argent
    } else if (rank == 3) {
      rankColor = Color(0xFFCD7F32); // Bronze
    } else {
      rankColor = Color(0xFFF9A825); // Jaune Afrolook
    }

    return GestureDetector(
      onTap: () {
        Navigator.of(context).pop();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LivePage(
              liveId: live.liveId!,
              isHost: live.hostId == authProvider.userId,
              hostName: live.hostName!,
              hostImage: live.hostImage!,
              isInvited: live.invitedUsers.contains(authProvider.userId),
              postLive: live,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: rankColor, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image du live avec badge de rang
            Expanded(
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                      image: DecorationImage(
                        image: NetworkImage(live.hostImage ?? ''),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  // Badge de rang
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: rankColor,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        rank <= 3 ? ["🥇", "🥈", "🥉"][rank-1] : "#$rank",
                        style: TextStyle(
                          fontSize: rank <= 3 ? 16 : 14,
                          fontWeight: FontWeight.bold,
                          color: rank <= 3 ? Colors.black : Colors.white,
                        ),
                      ),
                    ),
                  ),
                  // Badge LIVE
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, color: Colors.white, size: 8),
                          SizedBox(width: 4),
                          Text(
                            "LIVE",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Overlay gradient
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                      ),
                    ),
                  ),
                  // Nombre de viewers
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Row(
                      children: [
                        Icon(Icons.visibility, size: 12, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          "${live.viewerCount}",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Informations du live
            Padding(
              padding: EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    live.title,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Text(
                    "@${live.hostName}",
                    style: TextStyle(
                      fontSize: 10,
                      color: Color(0xFFF9A825),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Bouton rejoindre
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LivePage(
                        liveId: live.liveId!,
                        isHost: live.hostId == authProvider.userId,
                        hostName: live.hostName!,
                        hostImage: live.hostImage!,
                        isInvited: live.invitedUsers.contains(authProvider.userId),
                        postLive: live,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  "Rejoindre",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}




// class TopProductsGridModal {
//   static Future<void> showTopProductsGridModal(BuildContext context) async {
//     late CategorieProduitProvider     categorieProduitProvider = Provider.of<CategorieProduitProvider>(context, listen: false);
//     late UserAuthProvider     authProvider = Provider.of<UserAuthProvider>(context, listen: false);
//
//
//
//     // Charger les produits boostés
//    ;
//
//     final boostedProducts =  await categorieProduitProvider.getArticleBooster(authProvider.loginUserData.countryData?['countryCode'] ?? 'TG');
//     final hasBoostedProducts = boostedProducts.isNotEmpty;
//
//     showDialog(
//       context: context,
//       barrierDismissible: true,
//       builder: (BuildContext context) {
//         double height = MediaQuery.of(context).size.height;
//         double width = MediaQuery.of(context).size.width;
//
//         return Dialog(
//           backgroundColor: Colors.transparent,
//           insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
//           child: Container(
//             width: double.infinity,
//             constraints: BoxConstraints(maxWidth: 500, maxHeight: height * 0.8),
//             decoration: BoxDecoration(
//               color: Colors.black,
//               borderRadius: BorderRadius.circular(20),
//               border: Border.all(color: CustomConstants.kPrimaryColor, width: 2),
//               boxShadow: [
//                 BoxShadow(
//                   color: CustomConstants.kPrimaryColor.withOpacity(0.3),
//                   blurRadius: 15,
//                   spreadRadius: 2,
//                 ),
//               ],
//             ),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 // En-tête avec titre accrocheur
//                 Container(
//                   width: double.infinity,
//                   padding: EdgeInsets.all(16),
//                   decoration: BoxDecoration(
//                     gradient: LinearGradient(
//                       colors: [CustomConstants.kPrimaryColor, Colors.amber],
//                       begin: Alignment.topLeft,
//                       end: Alignment.bottomRight,
//                     ),
//                     borderRadius: BorderRadius.only(
//                       topLeft: Radius.circular(20),
//                       topRight: Radius.circular(20),
//                     ),
//                   ),
//                   child: Stack(
//                     children: [
//                       Center(
//                         child: Column(
//                           children: [
//                             Text(
//                               "🚀 PRODUITS BOOSTÉS 🚀",
//                               style: TextStyle(
//                                 fontSize: 20,
//                                 fontWeight: FontWeight.bold,
//                                 color: Colors.white,
//                               ),
//                             ),
//                             SizedBox(height: 8),
//                             Text(
//                               "Découvrez nos meilleures offres!",
//                               style: TextStyle(
//                                 fontSize: 14,
//                                 color: Colors.white70,
//                                 fontWeight: FontWeight.w500,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                       Positioned(
//                         right: 0,
//                         top: 0,
//                         child: GestureDetector(
//                           onTap: () => Navigator.of(context).pop(),
//                           child: Container(
//                             padding: EdgeInsets.all(4),
//                             decoration: BoxDecoration(
//                               color: Colors.black.withOpacity(0.3),
//                               shape: BoxShape.circle,
//                             ),
//                             child: Icon(
//                               Icons.close,
//                               color: Colors.white,
//                               size: 24,
//                             ),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//
//                 // Contenu principal
//                 if (hasBoostedProducts)
//                   _buildProductsGrid(context, boostedProducts, width, height)
//                 else
//                   _buildNoProductsContent(context),
//
//                 // Pied de page avec incitation
//                 Container(
//                   width: double.infinity,
//                   padding: EdgeInsets.all(16),
//                   decoration: BoxDecoration(
//                     color: Colors.grey[900],
//                     borderRadius: BorderRadius.only(
//                       bottomLeft: Radius.circular(20),
//                       bottomRight: Radius.circular(20),
//                     ),
//                   ),
//                   child: Column(
//                     children: [
//                       Text(
//                         "Boostez vos produits et multipliez vos ventes!",
//                         textAlign: TextAlign.center,
//                         style: TextStyle(
//                           fontSize: 16,
//                           fontWeight: FontWeight.bold,
//                           color: CustomConstants.kPrimaryColor,
//                         ),
//                       ),
//                       SizedBox(height: 8),
//                       Text(
//                         "Augmentez votre visibilité et atteignez plus de clients",
//                         textAlign: TextAlign.center,
//                         style: TextStyle(
//                           fontSize: 12,
//                           color: Colors.white70,
//                         ),
//                       ),
//                       SizedBox(height: 12),
//                       GestureDetector(
//                         onTap: () {
//                           Navigator.of(context).pop();
//                           // Naviguer vers la page des produits boostés
//                           Navigator.push(context, MaterialPageRoute(builder: (context) => HomeAfroshopPage(title: "")));
//                         },
//                         child: Row(
//                           mainAxisAlignment: MainAxisAlignment.center,
//                           children: [
//                             Icon(Icons.trending_up, color: Colors.amber, size: 16),
//                             SizedBox(width: 4),
//                             Text(
//                               "Voir plus de produits",
//                               style: TextStyle(
//                                 fontSize: 12,
//                                 color: Colors.amber,
//                                 fontWeight: FontWeight.w900,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }
//
//   static Widget _buildProductsGrid(BuildContext context, List<ArticleData> products, double width, double height) {
//     return Expanded(
//       child: Container(
//         padding: EdgeInsets.all(16),
//         child: GridView.builder(
//           shrinkWrap: true,
//           physics: AlwaysScrollableScrollPhysics(),
//           gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//             crossAxisCount: 2,
//             crossAxisSpacing: 12,
//             mainAxisSpacing: 12,
//             childAspectRatio: 0.75,
//           ),
//           itemCount: products.length,
//           itemBuilder: (context, index) {
//             return _ProductGridItem(
//               article: products[index],
//               width: width * 0.4,
//               height: height * 0.2,
//               rank: index + 1,
//             );
//           },
//         ),
//       ),
//     );
//   }
//
//   static Widget _buildNoProductsContent(BuildContext context) {
//     return Container(
//       padding: EdgeInsets.symmetric(vertical: 30, horizontal: 20),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Icon(
//             Icons.trending_up,
//             size: 64,
//             color: CustomConstants.kPrimaryColor,
//           ),
//           SizedBox(height: 16),
//           Text(
//             "Aucun produit boosté!",
//             style: TextStyle(
//               fontSize: 20,
//               fontWeight: FontWeight.bold,
//               color: Colors.white,
//             ),
//           ),
//           SizedBox(height: 12),
//           Text(
//             "Boostez vos produits pour les mettre en avant et augmenter vos ventes!",
//             textAlign: TextAlign.center,
//             style: TextStyle(
//               fontSize: 14,
//               color: Colors.grey[400],
//             ),
//           ),
//           SizedBox(height: 20),
//           ElevatedButton(
//             onPressed: () {
//               Navigator.of(context).pop();
//               // Naviguer vers la page de boost des produits
//               Navigator.push(context, MaterialPageRoute(builder: (context) => HomeAfroshopPage(title: "")));
//             },
//             style: ElevatedButton.styleFrom(
//               backgroundColor: CustomConstants.kPrimaryColor,
//               foregroundColor: Colors.white,
//               padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(12),
//               ),
//             ),
//             child: Text(
//               "BOOSTER MES PRODUITS",
//               style: TextStyle(
//                 fontSize: 16,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//           ),
//           SizedBox(height: 12),
//           Text(
//             "Augmentez votre visibilité de 500%!",
//             style: TextStyle(
//               fontSize: 12,
//               color: Colors.grey[500],
//               fontStyle: FontStyle.italic,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// class _ProductGridItem extends StatelessWidget {
//   final ArticleData article;
//   final double width;
//   final double height;
//   final int rank;
//
//   const _ProductGridItem({
//     required this.article,
//     required this.width,
//     required this.height,
//     required this.rank,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     Color rankColor;
//
//     if (rank == 1) {
//       rankColor = Color(0xFFFFD700); // Or
//     } else if (rank == 2) {
//       rankColor = Color(0xFFC0C0C0); // Argent
//     } else if (rank == 3) {
//       rankColor = Color(0xFFCD7F32); // Bronze
//     } else {
//       rankColor = CustomConstants.kPrimaryColor; // Vert Afrolook
//     }
//
//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.red,
//         // color: Colors.transparent,
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Stack(
//         children: [
//           // Utilisation du ProductWidget existant
//           Container(
//             color: Colors.green,
//
//             child: ProductWidget(
//               article: article,
//               width: width*5,
//               height: height*5,
//               isOtherPage: true,
//             ),
//           ),
//
//           // Badge de rang
//           Positioned(
//             top: 8,
//             left: 8,
//             child: Container(
//               width: 28,
//               height: 28,
//               alignment: Alignment.center,
//               decoration: BoxDecoration(
//                 color: rankColor,
//                 shape: BoxShape.circle,
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.black.withOpacity(0.3),
//                     blurRadius: 4,
//                     offset: Offset(0, 2),
//                   ),
//                 ],
//               ),
//               child: Text(
//                 rank <= 3 ? ["🥇", "🥈", "🥉"][rank-1] : "#$rank",
//                 style: TextStyle(
//                   fontSize: rank <= 3 ? 14 : 12,
//                   fontWeight: FontWeight.bold,
//                   color: rank <= 3 ? Colors.black : Colors.white,
//                 ),
//               ),
//             ),
//           ),
//
//           // Badge BOOSTÉ
//           Positioned(
//             top: 8,
//             right: 8,
//             child: Container(
//               padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
//               decoration: BoxDecoration(
//                 color: Colors.amber,
//                 borderRadius: BorderRadius.circular(12),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.black.withOpacity(0.3),
//                     blurRadius: 4,
//                     offset: Offset(0, 2),
//                   ),
//                 ],
//               ),
//               child: Row(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Icon(Icons.rocket_launch, color: Colors.black, size: 10),
//                   SizedBox(width: 4),
//                   Text(
//                     "BOOSTÉ",
//                     style: TextStyle(
//                       color: Colors.black,
//                       fontSize: 8,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }




///////////



// Ajoutez cette classe après les autres modals
// Modifiez la partie contenu principal du ChallengeModal




class TopProductsGridModal {
  static Future<void> showTopProductsGridModal(BuildContext context) async {
    late CategorieProduitProvider categorieProduitProvider = Provider.of<CategorieProduitProvider>(context, listen: false);
    late UserAuthProvider authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    late UserProvider userProvider = Provider.of<UserProvider>(context, listen: false);

    // Vérifier si l'utilisateur a une entreprise
    bool hasEntreprise = await userProvider.getUserEntreprise(authProvider.loginUserData.id!);

    // Charger les produits boostés
    final boostedProducts = await categorieProduitProvider.getArticleBooster(authProvider.loginUserData.countryData?['countryCode'] ?? 'TG');
    final hasBoostedProducts = boostedProducts.isNotEmpty;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        double height = MediaQuery.of(context).size.height;
        double width = MediaQuery.of(context).size.width;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(maxWidth: 500, maxHeight: height * 0.8),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: CustomConstants.kPrimaryColor, width: 2),
              boxShadow: [
                BoxShadow(
                  color: CustomConstants.kPrimaryColor.withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // En-tête avec titre accrocheur
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [CustomConstants.kPrimaryColor, Colors.amber],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.rocket_launch, color: Colors.white, size: 24),
                                SizedBox(width: 8),
                                Text(
                                  "PRODUITS STARS 🌟",
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(Icons.star, color: Colors.white, size: 24),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              "Les produits les plus populaires du moment!",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.3),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Contenu principal
                if (hasBoostedProducts)
                  _buildProductsGrid(context, boostedProducts, width, height)
                else
                  _buildNoProductsContent(context, hasEntreprise),

                // Pied de page avec incitation
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      if (hasEntreprise) ...[
                        Text(
                          "🚀 Vendez dans toute l'Afrique !",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Boostez vos produits et atteignez des millions de clients potentiels\nà travers 54 pays africains",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                        SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.public, color: Colors.green, size: 16),
                            SizedBox(width: 6),
                            Text(
                              "Visibilité panafricaine garantie",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Text(
                          "💼 Créez votre entreprise en 2 minutes !",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: CustomConstants.kPrimaryColor,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Rejoignez Afroshop et vendez vos produits\ndans toute l'Afrique dès aujourd'hui",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                        SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.flag, color: Colors.amber, size: 16),
                            SizedBox(width: 6),
                            Text(
                              "Marché de 1.4 milliard de consommateurs",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.amber,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          if (hasEntreprise) {
                            // Naviguer vers la page pour booster les produits
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => HomeAfroshopPage(title: "")
                                )
                            );
                          } else {
                            // Naviguer vers la création d'entreprise
                            Navigator.pushNamed(context, '/new_entreprise');
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: hasEntreprise ? Colors.amber : CustomConstants.kPrimaryColor,
                          foregroundColor: Colors.black,
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(hasEntreprise ? Icons.rocket_launch : Icons.business_center, size: 20),
                            SizedBox(width: 8),
                            Text(
                              hasEntreprise ? "BOOSTER MES PRODUITS" : "CRÉER MON ENTREPRISE",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 8),
                      if (hasEntreprise)
                        Text(
                          "Augmentez vos ventes de 300% en moyenne",
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.green,
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      else
                        Text(
                          "Gratuit • Rapide • Sans engagement",
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _buildProductsGrid(BuildContext context, List<ArticleData> products, double width, double height) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Bannière d'information
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              margin: EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: CustomConstants.kPrimaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: CustomConstants.kPrimaryColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: CustomConstants.kPrimaryColor, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Ces produits sont boostés et visibles dans toute l'Afrique",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Grille de produits
            Expanded(
              child: GridView.builder(
                shrinkWrap: true,
                physics: AlwaysScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.95,
                ),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  return _ProductGridItem(
                    article: products[index],
                    width: width * 0.4,
                    height: height * 0.2,
                    rank: index + 1,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildNoProductsContent(BuildContext context, bool hasEntreprise) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.trending_up,
            size: 64,
            color: CustomConstants.kPrimaryColor,
          ),
          SizedBox(height: 16),
          Text(
            hasEntreprise ? "Boostez votre premier produit! 🚀" : "Lancez votre business! 💼",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 12),
          Text(
            hasEntreprise
                ? "Soyez le premier à booster vos produits et dominez le marché africain !\n\nVos produits seront visibles dans 54 pays"
                : "Créez votre entreprise sur Afroshop et vendez vos produits dans toute l'Afrique !\n\nMarché de 1.4 milliard de consommateurs",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[400],
              height: 1.4,
            ),
          ),
          SizedBox(height: 20),
          if (hasEntreprise) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.public, color: Colors.green, size: 16),
                SizedBox(width: 6),
                Text(
                  "Visibilité panafricaine garantie",
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.visibility, color: Colors.amber, size: 16),
                SizedBox(width: 6),
                Text(
                  "500% plus de vues en moyenne",
                  style: TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people, color: CustomConstants.kPrimaryColor, size: 16),
                SizedBox(width: 6),
                Text(
                  "1.4 milliard de clients potentiels",
                  style: TextStyle(
                    color: CustomConstants.kPrimaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.speed, color: Colors.green, size: 16),
                SizedBox(width: 6),
                Text(
                  "Création en 2 minutes",
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _ProductGridItem extends StatelessWidget {
  final ArticleData article;
  final double width;
  final double height;
  final int rank;

  const _ProductGridItem({
    required this.article,
    required this.width,
    required this.height,
    required this.rank,
  });

  @override
  Widget build(BuildContext context) {
    Color rankColor;

    if (rank == 1) {
      rankColor = Color(0xFFFFD700); // Or
    } else if (rank == 2) {
      rankColor = Color(0xFFC0C0C0); // Argent
    } else if (rank == 3) {
      rankColor = Color(0xFFCD7F32); // Bronze
    } else {
      rankColor = CustomConstants.kPrimaryColor; // Vert Afrolook
    }

    return GestureDetector(
      onTap: () {
        Navigator.of(context).pop();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProduitDetail(productId: article.id!),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // Produit avec fond uniforme
              Container(
                color: Colors.grey[900],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Image du produit
                    Container(
                      height: height * 0.6,
                      child: CachedNetworkImage(
                        imageUrl: article.images?.isNotEmpty == true
                            ? article.images!.first
                            : '',
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[800],
                          child: Icon(Icons.shopping_bag, color: Colors.grey, size: 30),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[800],
                          child: Icon(Icons.shopping_bag, color: Colors.grey, size: 30),
                        ),
                      ),
                    ),

                    // Informations du produit
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.all(8),
                        color: Colors.grey[900],
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              article.titre ?? 'Produit',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${article.prix ?? 0} FCFA',
                              style: TextStyle(
                                color: CustomConstants.kPrimaryColor,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Badge de rang
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: rankColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    rank <= 3 ? ["🥇", "🥈", "🥉"][rank-1] : "#$rank",
                    style: TextStyle(
                      fontSize: rank <= 3 ? 14 : 12,
                      fontWeight: FontWeight.bold,
                      color: rank <= 3 ? Colors.black : Colors.white,
                    ),
                  ),
                ),
              ),

              // Badge BOOSTÉ
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.rocket_launch, color: Colors.black, size: 10),
                      SizedBox(width: 4),
                      Text(
                        "BOOSTÉ",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class ChallengeModal {
  static Future<void> showChallengeModal(BuildContext context, Challenge challenge) async {
    final authProvider = context.read<UserAuthProvider>();
    final currentUserId = authProvider.userId;

    final isInscrit = challenge.isInscrit(currentUserId);
    final aVote = challenge.aVote(currentUserId);
    final inscriptionsOuvertes = challenge.inscriptionsOuvertes;
    final peutParticiper = challenge.peutParticiper;
    final isEnCours = challenge.isEnCours;
    final isEnAttente = challenge.isEnAttente;


    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(maxWidth: 500, maxHeight: MediaQuery.of(context).size.height * 0.8),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.purple, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // En-tête avec titre accrocheur
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.purple, Colors.deepPurple],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Column(
                          children: [
                            Text(
                              "🏆 CHALLENGE EN COURS 🏆",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 8),
                            Text(
                              "Participez et gagnez des prix!",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Contenu principal du challenge avec SingleChildScrollView
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Titre du challenge
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.purple.withOpacity(0.3)),
                          ),
                          child: Text(
                            challenge.titre ?? 'Challenge',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(height: 12),

                        // Description avec limitation
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Description:',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                challenge.description ?? 'Aucune description',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[300],
                                  height: 1.4,
                                ),
                                maxLines: 3, // Limite à 3 lignes
                                overflow: TextOverflow.ellipsis, // Points de suspension si trop long
                              ),
                              if ((challenge.description?.length ?? 0) > 150) // Si description trop longue
                                GestureDetector(
                                  onTap: () {
                                    // Afficher la description complète dans un dialog
                                    _showFullDescription(context, challenge.description ?? '');
                                  },
                                  child: Padding(
                                    padding: EdgeInsets.only(top: 4),
                                    child: Text(
                                      'Voir plus...',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.purple,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16),

                        // Prix et récompense
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.purple),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.card_giftcard, color: Colors.amber, size: 24),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Prix à gagner',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[400],
                                      ),
                                    ),
                                    Text(
                                      '${challenge.prix ?? 0} FCFA',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.amber,
                                      ),
                                    ),
                                    // if (challenge.typeCadeaux != null)
                                    //   Text(
                                    //     challenge.typeCadeaux!,
                                    //     style: TextStyle(
                                    //       fontSize: 12,
                                    //       color: Colors.white,
                                    //     ),
                                    //     maxLines: 1,
                                    //     overflow: TextOverflow.ellipsis,
                                    //   ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16),

                        // Statistiques
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatItem(
                                Icons.people,
                                'Participants',
                                '${challenge.totalParticipants ?? 0}',
                              ),
                              _buildStatItem(
                                Icons.how_to_vote,
                                'Votes',
                                '${challenge.totalVotes ?? 0}',
                              ),
                              _buildStatItem(
                                Icons.visibility,
                                'Vues',
                                '${challenge.vues ?? 0}',
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16),

                        // État du challenge et dates
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.info, color: Colors.purple, size: 16),
                                  SizedBox(width: 8),
                                  Text(
                                    'État: ${_getStatusText(challenge.statut)}',
                                    style: TextStyle(
                                      color: _getStatusColor(challenge.statut),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              if (challenge.endInscriptionAt != null)
                                _buildDateItem(
                                  'Fin des inscriptions:',
                                  _formatDate(challenge.endInscriptionAt!),
                                ),
                              if (challenge.finishedAt != null)
                                _buildDateItem(
                                  'Fin du challenge:',
                                  _formatDate(challenge.finishedAt!),
                                ),
                            ],
                          ),
                        ),
                        SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),

                // Bouton d'action principal (toujours visible)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: _buildActionButton(context, challenge, isInscrit, aVote, inscriptionsOuvertes, peutParticiper),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Méthode pour afficher la description complète
  static void _showFullDescription(BuildContext context, String description) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.purple, width: 2),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.description, color: Colors.purple),
                  SizedBox(width: 8),
                  Text(
                    'Description complète',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[300],
                      height: 1.5,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16),
              Container(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Fermer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildStatItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.purple, size: 20),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[400],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  static Widget _buildDateItem(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 24), // Alignement avec le texte d'état
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[400],
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Les autres méthodes restent inchangées...
  static String _getStatusText(String? status) {
    switch (status) {
      case 'en_attente':
        return 'Inscriptions ouvertes';
      case 'en_cours':
        return 'Votes en cours';
      case 'termine':
        return 'Terminé';
      case 'annule':
        return 'Annulé';
      default:
        return 'Inconnu';
    }
  }

  static Color _getStatusColor(String? status) {
    switch (status) {
      case 'en_attente':
        return Colors.orange;
      case 'en_cours':
        return Colors.green;
      case 'termine':
        return Colors.blue;
      case 'annule':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  static String _formatDate(int microseconds) {
    final date = DateTime.fromMicrosecondsSinceEpoch(microseconds);
    return '${date.day}/${date.month}/${date.year}';
  }

  static Widget _buildActionButton(
      BuildContext context,
      Challenge challenge,
      bool isInscrit,
      bool aVote,
      bool inscriptionsOuvertes,
      bool peutParticiper,
      ) {
    String buttonText;
    VoidCallback onPressed;
    Color backgroundColor;

    if (challenge.isEnAttente) {
      if (isInscrit) {
        buttonText = "✅ DÉJÀ INSCRIT";
        onPressed = () {
          Navigator.of(context).pop();
          _navigateToChallengeDetails(context, challenge);
        };
        backgroundColor = Colors.green;
      } else {
        buttonText = "🎯 S'INSCRIRE AU CHALLENGE";
        onPressed = () {
          Navigator.of(context).pop();
          _navigateToChallengeDetails(context, challenge);
        };
        backgroundColor = Colors.purple;
      }
    } else if (challenge.isEnCours) {
      if (isInscrit) {
        if (aVote) {
          buttonText = "📊 VOIR LES VOTES";
          onPressed = () {
            Navigator.of(context).pop();
            _navigateToChallengeDetails(context, challenge);
          };
          backgroundColor = Colors.blue;
        } else {
          buttonText = "🗳️ ALLER VOTER";
          onPressed = () {
            Navigator.of(context).pop();
            _navigateToChallengeDetails(context, challenge);
          };
          backgroundColor = Colors.orange;
        }
      } else {
        buttonText = "👀 VOTER POUR LES PARTICIPANTS";
        onPressed = () {
          Navigator.of(context).pop();
          _navigateToChallengeDetails(context, challenge);
        };
        backgroundColor = Colors.deepPurple;
      }
    } else {
      buttonText = "📋 VOIR LES RÉSULTATS";
      onPressed = () {
        Navigator.of(context).pop();
        _navigateToChallengeDetails(context, challenge);
      };
      backgroundColor = Colors.grey;
    }

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Text(
        buttonText,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  static void _navigateToChallengeDetails(BuildContext context, Challenge challenge) {
    // Votre navigation vers la page de détails
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChallengeDetailPage(challengeId: challenge.id!),
      ),
    );
  }
}



// Ajoutez cette classe après les autres modals
class AfrolookInfoModal {
  static const String _lastInfoModalKey = 'last_info_modal';
  static const int _modalIntervalHours = 24; // Une fois par jour

  static Future<void> showAfrolookInfoModal(BuildContext context) async {
    final shouldShow = await _shouldShowModal();

    if (!shouldShow) {
      return; // Ne pas afficher si l'intervalle n'est pas écoulé
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.red, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // En-tête avec icône d'alerte
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.red, Colors.redAccent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Icône d'alerte principale
                      Column(
                        children: [
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.notifications_active,
                              color: Colors.red,
                              size: 40,
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            "🚨 NE MANQUEZ PAS ÇA ! 🚨",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Votre dose quotidienne d'Afrolook",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                      // Bouton fermer
                      Positioned(
                        top: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () {
                            Navigator.of(context).pop();
                            _markModalShown();
                            _showChallengeModalAfterInfo(context);
                          },
                          child: Container(
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.3),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Contenu informatif
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildInfoItem(
                          icon: Icons.live_tv,
                          title: "📡 ACTUALITÉS EN TEMPS RÉEL",
                          description: "Ne ratez plus jamais les annonces importantes ! Suivez en direct l'évolution de la plateforme, les nouvelles fonctionnalités et les événements exclusifs.",
                          color: Colors.red,
                          emoji: "🔥",
                        ),
                        SizedBox(height: 16),

                        _buildInfoItem(
                          icon: Icons.trending_up,
                          title: "💎 LES COULISSES AFROLOOK",
                          description: "Découvrez les secrets de notre succès ! Notre vision révolutionnaire, nos projets ambitieux et comment nous redéfinissons le digital africain.",
                          color: Colors.orange,
                          emoji: "🌟",
                        ),
                        SizedBox(height: 16),

                        _buildInfoItem(
                          icon: Icons.rocket_launch,
                          title: "💰 OPPORTUNITÉS EXCLUSIVES",
                          description: "Soyez parmi les premiers informés ! Investissements stratégiques, partenariats gagnants et opportunités réservées à notre communauté.",
                          color: Colors.green,
                          emoji: "💸",
                        ),
                        SizedBox(height: 16),

                        _buildInfoItem(
                          icon: Icons.celebration,
                          title: "🚀 PROJETS SECRETS EN PRÉPARATION",
                          description: "L'avenir s'écrit maintenant ! Découvrez en avant-première les innovations qui vont bouleverser votre expérience digitale.",
                          color: Colors.blue,
                          emoji: "🎯",
                        ),
                      ],
                    ),
                  ),
                ),

                // Section d'appel à l'action urgente
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    border: Border(
                      top: BorderSide(color: Colors.red.withOpacity(0.3)),
                      bottom: BorderSide(color: Colors.red.withOpacity(0.3)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "⚠️ Ces informations peuvent expirer bientôt !",
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Boutons d'action
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Message d'incitation
                      Container(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text(
                          "🎁 Des surprises attendent les plus curieux !",
                          style: TextStyle(
                            color: Colors.yellow,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      // Bouton principal URGENT
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _markModalShown();
                            _navigateToInfoPage(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 6,
                            shadowColor: Colors.red.withOpacity(0.5),
                          ),
                          icon: Icon(Icons.bolt, size: 24),
                          label: Text(
                            "🚀 DÉCOUVRIR MAINTENANT !",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 12),

                      // Sous-titre du bouton
                      Text(
                        "Rejoignez les initiés qui connaissent déjà ces informations exclusives",
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 12),

                      // Bouton secondaire avec message incitatif
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _markModalShown();
                              _showChallengeModalAfterInfo(context);
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.grey[500],
                              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.schedule, size: 16),
                                SizedBox(width: 4),
                                Text(
                                  "Plus tard",
                                  style: TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ),

                          // Compteur social
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.green.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.people, size: 12, color: Colors.green),
                                SizedBox(width: 4),
                                Text(
                                  "2.4K ont déjà vu",
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _buildInfoItem({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required String emoji,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Emoji et icône
          Column(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              SizedBox(height: 4),
              Text(
                emoji,
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[300],
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 8),
                // Badge d'urgence
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    "INFORMATION EXCLUSIVE",
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Future<bool> _shouldShowModal() async {
    final prefs = await SharedPreferences.getInstance();
    final lastShowTime = prefs.getInt(_lastInfoModalKey) ?? 0;
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    final intervalMs = _modalIntervalHours * 60 * 60 * 1000;

    return currentTime - lastShowTime > intervalMs;
  }

  static Future<void> _markModalShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastInfoModalKey, DateTime.now().millisecondsSinceEpoch);
    print('✅ Modal info Afrolook marqué comme affiché');
  }

  static void _navigateToInfoPage(BuildContext context) {
    // Navigation vers votre page d'information Afrolook
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AppInfos(), // Votre page d'information existante
      ),
    );
  }

  static void _showChallengeModalAfterInfo(BuildContext context) {
    // Afficher le modal challenge après la fermeture du modal info
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AdvancedModalManager.showModalsWithSmartDelay(context);
    });
  }

  // Méthode pour forcer l'affichage du modal (pour test)
  static Future<void> forceShowModal(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastInfoModalKey);
    await showAfrolookInfoModal(context);
  }

  // Méthode pour vérifier le statut
  static Future<void> debugInfoModalStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final lastShowTime = prefs.getInt(_lastInfoModalKey) ?? 0;
    final lastShown = lastShowTime > 0
        ? DateTime.fromMillisecondsSinceEpoch(lastShowTime)
        : 'jamais';

    final shouldShow = await _shouldShowModal();

    print('🔍 État du modal info Afrolook:');
    print('   - Dernier affichage: $lastShown');
    print('   - Doit être affiché: ${shouldShow ? "OUI" : "NON"}');
    print('   - Intervalle: $_modalIntervalHours heures');
  }
}
// Modifiez la classe AdvancedModalManager pour inclure les challenges

// Modifiez la classe AdvancedModalManager pour inclure le modal info en premier
class AdvancedModalManager {
  static const String _lastProductModalKey = 'last_product_modal3';
  static const String _lastLiveModalKey = 'last_live_modal2';
  static const String _lastChallengeModalKey = 'last_challenge_modal2';
  static const String _lastInfoModalKey = 'last_info_modal';
  static const String _lastTopFiveModalKey = 'last_top_five_modal'; // Nouvelle clé
  static const String _lastModalTypeKey = 'last_modal_type';
  static const int _modalIntervalHours = 4;
  static const int _infoModalIntervalHours = 24; // Une fois par jour
  static const int _challengeModalIntervalHours = 12; // 2 fois par jour
  static const int _topFiveModalIntervalHours = 6; // 4 fois par jour
  static bool _isShowingModal = false;

  static Future<void> showModalsWithSmartDelay(BuildContext context) async {
    if (_isShowingModal) {
      return;
    }

    _isShowingModal = true;

    try {
      await Future.delayed(Duration(milliseconds: 1500));

      // 🆕 ÉTAPE 1: Vérifier et afficher le modal info Afrolook
      final shouldShowInfo = await _shouldShowInfoModal();
      if (shouldShowInfo && context.mounted) {
        print('📢 Affichage du modal info Afrolook');
        await AfrolookInfoModal.showAfrolookInfoModal(context);
        return; // On s'arrête ici, le modal challenge viendra après
      }

      // 🏆 ÉTAPE 2: Vérifier et afficher le modal Top 5 Afrolookeur
      final shouldShowTopFive = await _shouldShowTopFiveModal();
      if (shouldShowTopFive && context.mounted) {
        print('👑 Tentative d\'affichage du modal Top 5 Afrolookeur');
        final success = await _tryShowTopFiveModal(context);
        if (success) {
          return; // On s'arrête ici si le modal a été affiché
        }
      }

      // 🎯 ÉTAPE 3: Vérifier les challenges
      final shouldShowChallenge = await _shouldShowChallengeModal();
      final activeChallenge = await _getActiveChallenge();

      if (activeChallenge != null && shouldShowChallenge && context.mounted) {
        print('🏆 Challenge actif trouvé: ${activeChallenge.titre}');
        await _showChallengeModal(context, activeChallenge);
        return;
      }

      // 🚫 ÉTAPE 4: Aucun modal prioritaire, afficher les autres modals
      print('❌ Aucun modal prioritaire, affichage des modals secondaires');
      final lastModalType = await _getLastModalType();

      if (lastModalType == 'products') {
        await _tryShowLiveModal(context);
      } else {
        await _tryShowProductModal(context);
      }

    } finally {
      _isShowingModal = false;
    }
  }

  // Nouvelle méthode pour le modal Top 5
  static Future<bool> _shouldShowTopFiveModal() async {
    final prefs = await SharedPreferences.getInstance();
    final lastShowTime = prefs.getInt(_lastTopFiveModalKey) ?? 0;
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    final intervalMs = _topFiveModalIntervalHours * 60 * 60 * 1000;

    return currentTime - lastShowTime > intervalMs;
  }

  // Nouvelle méthode pour afficher le modal Top 5
  static Future<bool> _tryShowTopFiveModal(BuildContext context) async {
    try {
      // Récupérer le UserProvider depuis le contexte
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      List<UserData> topAfrolookeurs = [];
if(userProvider.listAllUsers.isNotEmpty){
  topAfrolookeurs = userProvider.listAllUsers;
}else{
  topAfrolookeurs = await userProvider.getTopAfrolookeur();
}
      // Récupérer le top 5

      if (topAfrolookeurs.isNotEmpty) {
        final topFive = topAfrolookeurs.take(5).toList();
        print('👑 Top 5 récupéré avec ${topFive.length} utilisateurs');

        if (context.mounted) {
          await TopFiveModal.showTopFiveModal(context, topFive);
          await _markTopFiveModalShown();
          return true;
        }
      } else {
        print('👑 Aucun utilisateur trouvé pour le Top 5');
      }
    } catch (e) {
      print('❌ Erreur lors de l\'affichage du modal Top 5: $e');
    }

    return false;
  }

  // Nouvelle méthode pour marquer l'affichage du modal Top 5
  static Future<void> _markTopFiveModalShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastTopFiveModalKey, DateTime.now().millisecondsSinceEpoch);
    print('✅ Modal Top 5 marqué comme affiché à ${DateTime.now()}');
  }

  // Les méthodes existantes restent inchangées...
  static Future<bool> _shouldShowInfoModal() async {
    final prefs = await SharedPreferences.getInstance();
    final lastShowTime = prefs.getInt(_lastInfoModalKey) ?? 0;
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    final intervalMs = _infoModalIntervalHours * 60 * 60 * 1000;

    return currentTime - lastShowTime > intervalMs;
  }

  static Future<bool> _shouldShowChallengeModal() async {
    final prefs = await SharedPreferences.getInstance();
    final lastShowTime = prefs.getInt(_lastChallengeModalKey) ?? 0;
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    final intervalMs = _challengeModalIntervalHours * 60 * 60 * 1000;

    return currentTime - lastShowTime > intervalMs;
  }

  static Future<String> _getLastModalType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastModalTypeKey) ?? 'live';
  }

  static Future<void> _tryShowProductModal(BuildContext context) async {
    final shouldShowProducts = await _shouldShowModal(_lastProductModalKey);
    if (shouldShowProducts && context.mounted) {
      await _showProductModal(context);
      await _setLastModalType('products');
    } else {
      print('⏰ Modal produits non affiché');
    }
  }

  static Future<void> _tryShowLiveModal(BuildContext context) async {
    final shouldShowLives = await _shouldShowModal(_lastLiveModalKey);
    if (shouldShowLives && context.mounted) {
      await _showLiveModal(context);
      await _setLastModalType('lives');
    } else {
      print('⏰ Modal lives non affiché');
    }
  }

  static Future<void> _setLastModalType(String type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastModalTypeKey, type);
  }

  static Future<Challenge?> _getActiveChallenge() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Challenges')
          .where('statut', whereIn: ['en_attente', 'en_cours'])
          .where('disponible', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final challengeData = snapshot.docs.first.data();
        challengeData['id'] = snapshot.docs.first.id;
        return Challenge.fromJson(challengeData);
      }
      return null;
    } catch (e) {
      print('❌ Erreur lors de la récupération du challenge: $e');
      return null;
    }
  }

  static Future<void> _showProductModal(BuildContext context) async {
    print('🛒 Affichage du modal des produits boostés');
    await TopProductsGridModal.showTopProductsGridModal(context);
    await _markModalShown(_lastProductModalKey);
  }

  static Future<void> _showChallengeModal(BuildContext context, Challenge challenge) async {
    print('🏆 Affichage du modal du challenge: ${challenge.titre}');
    await ChallengeModal.showChallengeModal(context, challenge);
    await _markModalShown(_lastChallengeModalKey);
  }

  static Future<void> _showLiveModal(BuildContext context) async {
    print('🎥 Affichage du modal des lives');
    await TopLiveGridModal.showTopLiveGridModal(context);
    await _markModalShown(_lastLiveModalKey);
  }

  static Future<void> _markModalShown(String modalKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(modalKey, DateTime.now().millisecondsSinceEpoch);
    print('✅ Modal $modalKey marqué comme affiché à ${DateTime.now()}');
  }

  static Future<bool> _shouldShowModal(String modalKey) async {
    final prefs = await SharedPreferences.getInstance();
    final lastShowTime = prefs.getInt(modalKey) ?? 0;
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    final intervalMs = _modalIntervalHours * 60 * 60 * 1000;

    return currentTime - lastShowTime > intervalMs;
  }

  static Future<void> debugModalStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final productTime = prefs.getInt(_lastProductModalKey) ?? 0;
    final liveTime = prefs.getInt(_lastLiveModalKey) ?? 0;
    final challengeTime = prefs.getInt(_lastChallengeModalKey) ?? 0;
    final infoTime = prefs.getInt(_lastInfoModalKey) ?? 0;
    final topFiveTime = prefs.getInt(_lastTopFiveModalKey) ?? 0; // Nouveau
    final lastModalType = prefs.getString(_lastModalTypeKey) ?? 'aucun';

    final now = DateTime.now();
    final productShown = productTime > 0 ? DateTime.fromMillisecondsSinceEpoch(productTime) : null;
    final liveShown = liveTime > 0 ? DateTime.fromMillisecondsSinceEpoch(liveTime) : null;
    final challengeShown = challengeTime > 0 ? DateTime.fromMillisecondsSinceEpoch(challengeTime) : null;
    final infoShown = infoTime > 0 ? DateTime.fromMillisecondsSinceEpoch(infoTime) : null;
    final topFiveShown = topFiveTime > 0 ? DateTime.fromMillisecondsSinceEpoch(topFiveTime) : null; // Nouveau

    final activeChallenge = await _getActiveChallenge();
    final shouldShowInfo = await _shouldShowInfoModal();
    final shouldShowChallenge = await _shouldShowChallengeModal();
    final shouldShowTopFive = await _shouldShowTopFiveModal(); // Nouveau

    print('🔍 État des modals:');
    print('   - Dernier modal: $lastModalType');
    print('   - Modal Info: ${shouldShowInfo ? "À AFFICHER" : "PAS MAINTENANT"} (affiché: ${infoShown ?? "jamais"})');
    print('   - Modal Top 5: ${shouldShowTopFive ? "À AFFICHER" : "PAS MAINTENANT"} (affiché: ${topFiveShown ?? "jamais"})'); // Nouveau
    print('   - Modal Challenge: ${shouldShowChallenge ? "À AFFICHER" : "PAS MAINTENANT"} (affiché: ${challengeShown ?? "jamais"})');
    print('   - Challenge actif: ${activeChallenge != null ? "OUI" : "NON"}');
    print('   - Produits affichés: ${productShown ?? "jamais"}');
    print('   - Lives affichés: ${liveShown ?? "jamais"}');

    if (shouldShowInfo) {
      print('   📢 PRIORITÉ: Modal Info Afrolook');
    } else if (shouldShowTopFive) {
      print('   👑 PRIORITÉ: Modal Top 5 Afrolookeur');
    } else if (activeChallenge != null && shouldShowChallenge) {
      print('   🎯 PRIORITÉ: Modal Challenge');
    } else {
      print('   🚫 Aucun modal prioritaire - modals secondaires');
    }
  }

  static Future<void> resetAllModals() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastProductModalKey);
    await prefs.remove(_lastLiveModalKey);
    await prefs.remove(_lastChallengeModalKey);
    await prefs.remove(_lastInfoModalKey);
    await prefs.remove(_lastTopFiveModalKey); // Nouveau
    await prefs.remove(_lastModalTypeKey);
    print('🔄 Tous les modals ont été réinitialisés');
  }
}

class AdvancedModalManager2 {
  static const String _lastProductModalKey = 'last_product_modal3';
  static const String _lastLiveModalKey = 'last_live_modal2';
  static const String _lastChallengeModalKey = 'last_challenge_modal2';
  static const String _lastModalTypeKey = 'last_modal_type';
  static const int _modalIntervalHours = 4;
  static bool _isShowingModal = false;

  static Future<void> showModalsWithSmartDelay(BuildContext context) async {
    if (_isShowingModal) {
      return;
    }

    _isShowingModal = true;

    try {
      await Future.delayed(Duration(milliseconds: 1500));

      // 🔥 NOUVELLE LOGIQUE : Toujours vérifier les challenges en premier
      final activeChallenge = await _getActiveChallenge();

      if (activeChallenge != null && context.mounted) {
        // 🎯 IL Y A UN CHALLENGE ACTIF - On l'affiche sans vérifier l'intervalle
        print('🏆 Challenge actif trouvé: ${activeChallenge.titre}');

        await _showChallengeModal(context, activeChallenge);
        return; // On s'arrête ici, pas d'autres modals
      }

      // 🚫 AUCUN CHALLENGE ACTIF - On continue avec les autres modals
      print('❌ Aucun challenge actif, affichage des autres modals');
      final prefs = await SharedPreferences.getInstance();
      final lastModalType = prefs.getString(_lastModalTypeKey) ?? 'live';

      if (lastModalType == 'products') {
        await _tryShowLiveModal(context, prefs);
      } else {
        await _tryShowProductModal(context, prefs);
      }

    } finally {
      _isShowingModal = false;
    }
  }

  static Future<Challenge?> _getActiveChallenge() async {
    try {
      // Récupération directe depuis Firebase
      final snapshot = await FirebaseFirestore.instance
          .collection('Challenges')
          .where('statut', whereIn: ['en_attente', 'en_cours'])
          .where('disponible', isEqualTo: true)
          // .where('isAprouved', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final challengeData = snapshot.docs.first.data();
        challengeData['id'] = snapshot.docs.first.id;
        // FirebaseFirestore.instance.collection('Challenges').doc(snapshot.docs.first.id).update({
        //   'vues': FieldValue.increment(1),
        // });

        return Challenge.fromJson(challengeData);
      }
      return null;
    } catch (e) {
      print('❌ Erreur lors de la récupération du challenge: $e');
      return null;
    }
  }

  static Future<void> _showChallengeModal(BuildContext context, Challenge challenge) async {

    print('🏆 Affichage du modal du challenge: ${challenge.titre}');
    await ChallengeModal.showChallengeModal(context, challenge);

    // On marque quand même l'affichage pour le debug, mais sans bloquer les prochains
    await _markModalShown(_lastChallengeModalKey);
  }

  // 🚫 LES AUTRES MODALS NE S'AFFICHENT QUE SI PAS DE CHALLENGE
  static Future<void> _tryShowProductModal(BuildContext context, SharedPreferences prefs) async {
    final shouldShowProducts = await _shouldShowModal(_lastProductModalKey);
    if (shouldShowProducts && context.mounted) {
      await _showProductModal(context);
      await prefs.setString(_lastModalTypeKey, 'products');
    } else {
      print('⏰ Modal produits non affiché (intervalle pas encore écoulé)');
    }
  }

  static Future<void> _tryShowLiveModal(BuildContext context, SharedPreferences prefs) async {
    final shouldShowLives = await _shouldShowModal(_lastLiveModalKey);
    if (shouldShowLives && context.mounted) {
      await _showLiveModal(context);
      await prefs.setString(_lastModalTypeKey, 'lives');
    } else {
      print('⏰ Modal lives non affiché (intervalle pas encore écoulé)');
    }
  }

  static Future<void> _showProductModal(BuildContext context) async {
    print('🛒 Affichage du modal des produits boostés');
    await TopProductsGridModal.showTopProductsGridModal(context);
    await _markModalShown(_lastProductModalKey);
  }

  static Future<void> _showLiveModal(BuildContext context) async {
    print('🎥 Affichage du modal des lives');
    await TopLiveGridModal.showTopLiveGridModal(context);
    await _markModalShown(_lastLiveModalKey);
  }

  static Future<bool> _shouldShowModal(String modalKey) async {
    final prefs = await SharedPreferences.getInstance();
    final lastShowTime = prefs.getInt(modalKey) ?? 0;
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    final intervalMs = _modalIntervalHours * 60 * 60 * 1000;

    return currentTime - lastShowTime > intervalMs;
  }

  static Future<void> _markModalShown(String modalKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(modalKey, DateTime.now().millisecondsSinceEpoch);
    print('✅ Modal $modalKey marqué comme affiché à ${DateTime.now()}');
  }

  static Future<void> debugModalStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final productTime = prefs.getInt(_lastProductModalKey) ?? 0;
    final liveTime = prefs.getInt(_lastLiveModalKey) ?? 0;
    final challengeTime = prefs.getInt(_lastChallengeModalKey) ?? 0;
    final lastModalType = prefs.getString(_lastModalTypeKey) ?? 'aucun';

    final now = DateTime.now();
    final productShown = productTime > 0 ? DateTime.fromMillisecondsSinceEpoch(productTime) : null;
    final liveShown = liveTime > 0 ? DateTime.fromMillisecondsSinceEpoch(liveTime) : null;
    final challengeShown = challengeTime > 0 ? DateTime.fromMillisecondsSinceEpoch(challengeTime) : null;

    // Vérifier les challenges actifs
    final activeChallenge = await _getActiveChallenge();

    print('🔍 État des modals:');
    print('   - Dernier modal: $lastModalType');
    print('   - Challenge actif: ${activeChallenge != null ? "OUI (" + activeChallenge.titre! + ")" : "NON"}');
    print('   - Produits affichés: ${productShown ?? "jamais"}');
    print('   - Lives affichés: ${liveShown ?? "jamais"}');
    print('   - Challenges affichés: ${challengeShown ?? "jamais"}');

    if (activeChallenge != null) {
      print('   🎯 PRIORITÉ: Les challenges bloquent les autres modals');
    } else {
      print('   🚫 Aucun challenge actif - les autres modals peuvent s\'afficher');
    }
  }

  static Future<void> resetAllModals() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastProductModalKey);
    await prefs.remove(_lastLiveModalKey);
    await prefs.remove(_lastChallengeModalKey);
    await prefs.remove(_lastModalTypeKey);
    print('🔄 Tous les modals ont été réinitialisés');
  }

  // 🔥 NOUVELLE MÉTHODE : Vérifier rapidement s'il y a des challenges
  static Future<bool> hasActiveChallenges() async {
    final challenge = await _getActiveChallenge();
    return challenge != null;
  }
}

