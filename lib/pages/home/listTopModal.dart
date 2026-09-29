import '../../utils/platform_guard.dart';
import 'package:afrotok/pages/LiveAgora/live_list_page.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';

import 'package:afrotok/pages/afroshop/marketPlace/acceuil/home_afroshop.dart';

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

import '../dating/dating_entry_page.dart';

import '../info.dart';

import '../user/mes_gains_post_page.dart';

import '../../theme/app_colors.dart';

import '../../l10n/app_localizations.dart';

import 'package:flutter_animate/flutter_animate.dart';
import '../../services/utils/abonnement_utils.dart';
import '../user/userAbonnementPage.dart';

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
        final colors = AppColors.of(context);
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.accent, width: 2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // En-tête avec croix
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.primary.withOpacity(0.7),
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
                                    color: colors.accent,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  "Découvrez les stars du jour!",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: colors.onPrimary,
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
                                color: colors.accent,
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
                        color: colors.primary.withOpacity(0.3),
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
                          backgroundColor: colors.accent,
                          foregroundColor: colors.onAccent,
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
              ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0, duration: 300.ms, curve: Curves.easeOut);
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
    final colors = AppColors.of(context);
    Color rankColor;
    IconData rankIcon;

    if (rank == 1) {
      rankColor = colors.accent;
      rankIcon = Icons.emoji_events;
    } else if (rank == 2) {
      rankColor = Colors.grey[400]!;
      rankIcon = Icons.workspace_premium;
    } else if (rank == 3) {
      rankColor = Colors.orange[800]!;
      rankIcon = Icons.workspace_premium;
    } else {
      rankColor = colors.primary;
      rankIcon = Icons.star;
    }

    return Container(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
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
              CircleAvatar(onBackgroundImageError: (_, __) {}, 
                backgroundImage: NetworkImage(user.imageUrl ?? ''),
                radius: 24,
                backgroundColor: colors.surfaceVariant,
              ),
              if (user.isVerify ?? false)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.verified,
                      color: colors.primary,
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
                    color: colors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),

                SizedBox(height: 4),

                // FOLLOWERS
                Row(
                  children: [
                    Icon(Icons.people, size: 14, color: colors.primary),
                    SizedBox(width: 4),
                    Text(
                      "${user.followersCount} abonnés",
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 2),

                // ⭐ POPULARITÉ
                Row(
                  children: [
                    Icon(Icons.star, size: 12, color: colors.accent),
                    SizedBox(width: 4),
                    Text(
                      "${(user.popularite ?? 0).toStringAsFixed(2)}%",
                      style: TextStyle(
                        fontSize: 10,
                        color: colors.textSecondary,
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
    ).animate().fadeIn(duration: 300.ms, delay: (40 * rank).ms).slideX(begin: -0.05, end: 0, duration: 300.ms, curve: Curves.easeOut);
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
        final colors = AppColors.of(context);
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(maxWidth: 500),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.accent, width: 2),
              boxShadow: [
                BoxShadow(
                  color: colors.accent.withOpacity(0.3),
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
                      colors: [colors.accent, colors.danger],
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
                                color: colors.onAccent,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              "Rejoignez l'expérience en direct!",
                              style: TextStyle(
                                fontSize: 14,
                                color: colors.onAccent.withOpacity(0.87),
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
                            color: colors.onAccent,
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
                    color: colors.surfaceVariant,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        kIsAppleStore ? "En faisant un live, vous pouvez gagner beaucoup de pièces !" : "En faisant un live, vous pouvez gagner plus de 50 000 FCFA!",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colors.accent,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Partagez vos talents avec la communauté Afrolook",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textSecondary,
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
                            Icon(Icons.live_tv, color: colors.danger, size: 16),
                            SizedBox(width: 4),
                            Text(
                              "Voir plus de lives",
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.danger,
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
          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0, duration: 300.ms, curve: Curves.easeOut),
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
    final colors = AppColors.of(context);
    return Container(
      padding: EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.videocam_off,
            size: 64,
            color: colors.danger,
          ),
          SizedBox(height: 16),
          Text(
            "Aucun live en cours!",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          SizedBox(height: 12),
          Text(
            "Soyez le premier à lancer un live et attirez l'attention de la communauté!",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: colors.textSecondary,
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
              backgroundColor: colors.danger,
              foregroundColor: colors.onPrimary,
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
              color: colors.textSecondary,
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
    final colors = AppColors.of(context);
    Color rankColor;

    if (rank == 1) {
      rankColor = Color(0xFFFFD700); // Or
    } else if (rank == 2) {
      rankColor = Color(0xFFC0C0C0); // Argent
    } else if (rank == 3) {
      rankColor = Color(0xFFCD7F32); // Bronze
    } else {
      rankColor = colors.accent; // Jaune Afrolook
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
          color: colors.surfaceVariant,
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
                      image: (live.hostImage?.isNotEmpty == true)
                          ? DecorationImage(
                              image: NetworkImage(live.hostImage!),
                              fit: BoxFit.cover,
                            )
                          : null,
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
                          color: rank <= 3 ? colors.black : colors.textPrimary,
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
                        color: colors.danger,
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
                      color: colors.textPrimary,
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
                      color: colors.accent,
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
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
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
    ).animate().fadeIn(duration: 300.ms, delay: (50 * rank).ms).scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1), duration: 300.ms, curve: Curves.easeOut);
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
        final colors = AppColors.of(context);
        double height = MediaQuery.of(context).size.height;
        double width = MediaQuery.of(context).size.width;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(maxWidth: 500, maxHeight: height * 0.8),
            decoration: BoxDecoration(
              color: colors.surface,
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
                                Icon(Icons.rocket_launch, color: colors.onPrimary, size: 24),
                                SizedBox(width: 8),
                                Text(
                                  "PRODUITS STARS 🌟",
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: colors.onPrimary,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(Icons.star, color: colors.onPrimary, size: 24),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              "Les produits les plus populaires du moment!",
                              style: TextStyle(
                                fontSize: 14,
                                color: colors.onPrimary.withOpacity(0.7),
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
                              color: colors.onPrimary,
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
                    color: colors.surfaceVariant,
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
                            color: colors.textSecondary,
                          ),
                        ),
                        SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.public, color: colors.primary, size: 16),
                            SizedBox(width: 6),
                            Text(
                              "Visibilité panafricaine garantie",
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.primary,
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
                            color: colors.textSecondary,
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
                          foregroundColor: colors.onPrimary,
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
                            color: colors.primary,
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      else
                        Text(
                          "Gratuit • Rapide • Sans engagement",
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0, duration: 300.ms, curve: Curves.easeOut),
        );
      },
    );
  }

  static Widget _buildProductsGrid(BuildContext context, List<ArticleData> products, double width, double height) {
    final colors = AppColors.of(context);
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
                        color: colors.textSecondary,
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
    final colors = AppColors.of(context);
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
              color: colors.textPrimary,
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
              color: colors.textSecondary,
              height: 1.4,
            ),
          ),
          SizedBox(height: 20),
          if (hasEntreprise) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.public, color: colors.primary, size: 16),
                SizedBox(width: 6),
                Text(
                  "Visibilité panafricaine garantie",
                  style: TextStyle(
                    color: colors.primary,
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
                Icon(Icons.speed, color: colors.primary, size: 16),
                SizedBox(width: 6),
                Text(
                  "Création en 2 minutes",
                  style: TextStyle(
                    color: colors.primary,
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
    final colors = AppColors.of(context);
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
                color: colors.surfaceVariant,
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
                          color: colors.shimmerBase,
                          child: Icon(Icons.shopping_bag, color: colors.textSecondary, size: 30),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: colors.shimmerBase,
                          child: Icon(Icons.shopping_bag, color: colors.textSecondary, size: 30),
                        ),
                      ),
                    ),

                    // Informations du produit
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.all(8),
                        color: colors.surfaceVariant,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              article.titre ?? 'Produit',
                              style: TextStyle(
                                color: colors.textPrimary,
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
                      color: rank <= 3 ? colors.black : colors.textPrimary,
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
                      Icon(Icons.rocket_launch, color: colors.black, size: 10),
                      SizedBox(width: 4),
                      Text(
                        "BOOSTÉ",
                        style: TextStyle(
                          color: colors.black,
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
    ).animate().fadeIn(duration: 300.ms, delay: (40 * rank).ms).scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1), duration: 300.ms, curve: Curves.easeOut);
  }
}

// Modifiez la classe AdvancedModalManager pour inclure les challenges


Future<void> showRemunerationAnnounceModal(BuildContext context, String userId) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      final colors = AppColors.of(context);
      final t      = AppLocalizations.of(context);
      const gold   = Color(0xFFFFD700);

      return WillPopScope(
        onWillPop: () async => false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: gold.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(color: gold.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 4)),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Badge NOUVEAU
                Align(
                  alignment: Alignment.topRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('NOUVEAU',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold,
                            letterSpacing: 1)),
                  ),
                ),
                const SizedBox(height: 4),

                // Icône
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: gold.withOpacity(0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.monetization_on_rounded, color: gold, size: 32),
                ),
                const SizedBox(height: 12),

                // Titre
                Text(t.remuModalTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: gold, fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),

                // Description
                Text(t.remuModalDesc,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                const SizedBox(height: 12),

                // Badge taux central
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: gold.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: gold.withOpacity(0.4)),
                  ),
                  child: Text(t.remuModalRate,
                      style: const TextStyle(color: gold, fontSize: 16, fontWeight: FontWeight.bold,
                          letterSpacing: 0.5)),
                ),
                const SizedBox(height: 14),

                // 3 points clés
                _remuPoint(Icons.check_circle_outline, t.remuModalPoint1, colors),
                const SizedBox(height: 6),
                _remuPoint(Icons.check_circle_outline, t.remuModalPoint2, colors),
                const SizedBox(height: 6),
                _remuPoint(Icons.check_circle_outline, t.remuModalPoint3, colors),
                const SizedBox(height: 20),

                // Boutons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                        child: Text(t.remuModalLater,
                            style: TextStyle(color: colors.textSecondary, fontSize: 13,
                                fontWeight: FontWeight.w500)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(context,
                              MaterialPageRoute(builder: (_) => MesGainsPage(userId: userId)));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: gold,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(t.remuModalBtn,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0, duration: 300.ms, curve: Curves.easeOut),
          ),
        ),
      );
    },
  );
}

Widget _remuPoint(IconData icon, String text, AppColors colors) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: colors.primary, size: 16),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: TextStyle(color: colors.textPrimary, fontSize: 12))),
    ],
  );
}