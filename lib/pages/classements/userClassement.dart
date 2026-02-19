import 'dart:math';
import 'package:afrotok/models/model_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../../constant/constColors.dart';
import '../../../constant/logo.dart';
import '../../../constant/sizeText.dart';
import '../../../constant/textCustom.dart';
import '../../providers/authProvider.dart';
import '../../providers/postProvider.dart';
import '../../providers/userProvider.dart';
import '../auth/authTest/constants.dart';
import '../component/showUserDetails.dart';
import '../home/listTopModal.dart';
import '../pub/native_ad_widget.dart';
import '../user/detailsOtherUser.dart';

class UserClassement extends StatefulWidget {
  const UserClassement({super.key});

  @override
  State<UserClassement> createState() => _UserClassementState();
}

class _UserClassementState extends State<UserClassement> {
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  late UserProvider userProvider =
  Provider.of<UserProvider>(context, listen: false);
  late PostProvider postProvider =
  Provider.of<PostProvider>(context, listen: false);

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Simuler un temps de chargement pour voir l'effet shimmer
    await Future.delayed(Duration(seconds: 1));
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;

    // Trier les utilisateurs par popularité (du plus élevé au plus bas)
    List<UserData> sortedUsers = List.from(userProvider.listAllUsers);
    sortedUsers.sort((a, b) => (b.popularite ?? 0).compareTo(a.popularite ?? 0));

    // Prendre les 10 premiers
    List<UserData> topUsers = sortedUsers.take(10).toList();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          "TOP 10 Afrolook Stars",
          style: TextStyle(
            fontSize: SizeText.homeProfileTextSize,
            color: Colors.yellow[700],
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Logo(),
          )
        ],
        iconTheme: IconThemeData(color: Colors.yellow[700]),
      ),
      body: _isLoading
          ? _buildShimmerLoading()
          : SingleChildScrollView(
        physics: BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // En-tête avec informations
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[800]?.withOpacity(0.3),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Classement par popularité",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[400],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Période 1 Décembre 2024 - ...",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.yellow[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    "Les stars sont classées selon leur activité: publications, likes et commentaires",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 16),

            // Liste des top 10 avec pub en premier élément
            ListView.builder(
              itemCount: topUsers.length + 1, // +1 pour la pub
              shrinkWrap: true,
              padding: EdgeInsets.only(top: 8, bottom: 20),
              physics: NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                // Premier élément (index 0) = la pub
                if (index == 0) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: _buildAdBanner(key: 'top10_first_ad'),
                  );
                }

                // Ajuster l'index pour les utilisateurs
                final userIndex = index - 1;

                return GestureDetector(
                  onTap: () {
                    showUserDetailsModalDialog(topUsers[userIndex], width, height, context);
                  },
                  child: TopFiveUserItem(
                    user: topUsers[userIndex],
                    rank: userIndex + 1,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

// ✅ Version avec shimmer loading incluant la pub
  Widget _buildShimmerLoading() {
    return ListView.builder(
      itemCount: 11, // +1 pour la pub
      shrinkWrap: true,
      padding: EdgeInsets.only(top: 16),
      itemBuilder: (context, index) {
        // Premier élément (index 0) = placeholder de pub
        if (index == 0) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Shimmer.fromColors(
              baseColor: Colors.grey[800]!,
              highlightColor: Colors.grey[700]!,
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          );
        }

        return Shimmer.fromColors(
          baseColor: Colors.grey[800]!,
          highlightColor: Colors.grey[700]!,
          child: Container(
            padding: EdgeInsets.all(16),
            margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 120,
                        height: 16,
                        color: Colors.white,
                      ),
                      SizedBox(height: 8),
                      Container(
                        width: 80,
                        height: 12,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 60,
                  height: 16,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

// ✅ Ajoutez cette fonction dans votre classe
  Widget _buildAdBanner({required String key}) {
    return Container(
      key: ValueKey(key),
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: NativeAdWidget(
        templateType: TemplateType.small,
        onAdLoaded: () {
          print('✅ Native Ad chargée dans top10: $key');
        },
      ),
    );
  }
}

class _UserRankItem extends StatelessWidget {
  final UserData user;
  final int rank;
  final bool isTop3;

  const _UserRankItem({
    required this.user,
    required this.rank,
    required this.isTop3,
  });

  @override
  Widget build(BuildContext context) {
    // Définir les couleurs en fonction du rang
    Color rankColor;
    if (rank == 1) {
      rankColor = Colors.yellow[700]!;
    } else if (rank == 2) {
      rankColor = Colors.grey[400]!;
    } else if (rank == 3) {
      rankColor = Colors.orange[800]!;
    } else {
      rankColor = Colors.green[600]!;
    }

    return Container(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Numéro de classement
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: rankColor,
              shape: BoxShape.circle,
            ),
            child: Text(
              "$rank",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),

          SizedBox(width: 12),

          // Avatar utilisateur
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

          // Informations utilisateur
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
                    Icon(Icons.people, size: 12, color: Colors.green[600]),
                    SizedBox(width: 4),
                    Text(
                      "${user.userAbonnesIds!.length ?? 0} abonnés",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[400],
                      ),
                    ),
                    SizedBox(width: 12),
                    Icon(Icons.star, size: 12, color: Colors.yellow[700]),
                    // SizedBox(width: 4),
                    // Text(
                    //   "${(user.popularite ?? 0 * 100).toStringAsFixed(1)}%",
                    //   style: TextStyle(
                    //     fontSize: 12,
                    //     color: Colors.yellow[700],
                    //   ),
                    // ),
                  ],
                ),
              ],
            ),
          ),

          // // Points
          // Container(
          //   padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          //   decoration: BoxDecoration(
          //     color: Colors.green[900]?.withOpacity(0.5),
          //     borderRadius: BorderRadius.circular(12),
          //   ),
          //   child: Text(
          //     "${user.pointContribution ?? 0} pts",
          //     style: TextStyle(
          //       fontSize: 12,
          //       fontWeight: FontWeight.bold,
          //       color: Colors.green[400],
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }
}