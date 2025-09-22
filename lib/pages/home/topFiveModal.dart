import 'package:afrotok/pages/LiveAgora/live_list_page.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/model_data.dart';
import '../LiveAgora/livesAgora.dart';
import '../classements/userClassement.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/models/model_data.dart';
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

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                Row(
                  children: [
                    Icon(Icons.people, size: 14, color: Colors.green[600]),
                    SizedBox(width: 4),
                    Text(
                      "${user.userAbonnesIds!.length ?? 0} abonnés",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

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
              // Navigator.push(context, MaterialPageRoute(builder: (context) => CreateLivePage()));
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