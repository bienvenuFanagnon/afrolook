import 'package:afrotok/models/model_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:provider/provider.dart';
import '../../../constant/logo.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/postProvider.dart';
import '../../../providers/userProvider.dart';
import '../../../theme/app_colors.dart';
import '../../admin/AfrolookPub/afrolookAdminPubPage.dart';
import '../../admin/admin_email_screen.dart';
import '../../admin/dating/admin_dating_profiles_page.dart';
import '../../canaux/listCanauxByUser.dart';
import '../../challenge/challengeDashbord.dart';
import '../../pronostics/admin_pronostics_page.dart';
import '../../userPosts/favorites_posts.dart';
import '../otherUser/otherUser.dart';
import '../remuneration_home_page.dart';
import '../userAbonnementPage.dart';
import '../userPubs/user_my_advertisements_page.dart';
import 'adminprofil.dart';
class UserProfil extends StatefulWidget {
  const UserProfil({super.key});

  @override
  State<UserProfil> createState() => _UserProfilState();
}

class _UserProfilState extends State<UserProfil> {
  late AppColors _colors;

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
    _colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);

    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;

    // Définition des couleurs du thème
    final Color primaryBlack = _colors.background;
    final Color primaryRed = _colors.danger;
    final Color primaryYellow = _colors.accent;
    final Color secondaryBlack = _colors.surface;
    final Color textWhite = _colors.textPrimary;
    final Color textGrey = _colors.textSecondary;

    return Scaffold(
      backgroundColor: primaryBlack,
      appBar: AppBar(
        backgroundColor: primaryBlack,
        elevation: 0,
        title: Text(
          l10n.profileTitle,
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
                                      l10n.profileFollowers,
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
                                  color: _colors.divider,
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
                                      l10n.profileLikesShort,
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
                            l10n.profileMyLooks,
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
                          label: l10n.profileMenuMyInfos,
                          color: Colors.blue,
                          onTap: () {
                            Navigator.pushNamed(context, '/profil_detail_user');
                          },
                        ),
                        _buildMenuButton(
                          icon: Icons.store,
                          label: l10n.profileMenuEnterprise,
                          color: Color(0xFF2ECC71),
                          onTap: () async {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => Scaffold(
                                  backgroundColor: _colors.background,
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
                                            l10n.profileEnterpriseCreateTitle,
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: textWhite,
                                            ),
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            l10n.profileEnterpriseCreateDesc,
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
                                            child: Text(l10n.profileEnterpriseCreateBtn, style: TextStyle(color: Colors.white)),
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
                                  content: Text(l10n.profileEnterpriseLoadError),
                                  backgroundColor: primaryRed,
                                ),
                              );
                            }
                          },
                        ),
                        _buildMenuButton(
                          icon: Icons.monetization_on,
                          label: l10n.profileMenuRemunerationSpace,
                          color: Colors.green,
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => RemunerationHomePage(user: authProvider.loginUserData!,)));
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
                          label: l10n.profileMenuSubscription,
                          color: Colors.blue,
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => AbonnementScreen()));
                          },
                        ),
                        _buildMenuButton(
                          icon: Icons.bookmark_border,
                          label: l10n.profileMenuFavorites,
                          color: primaryYellow,
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => FavoritePostsPage()));
                          },
                        ),
                        _buildMenuButton(
                          icon: FontAwesome.forumbee,
                          label: l10n.profileMenuChannels,
                          color: Colors.green,
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => CanalListPageByUser()));
                          },
                        ),
                      ],
                    ),

                    SizedBox(height: 15),
                    // Ligne 3
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMenuButton(
                          icon: Icons.public,
                          label: l10n.profileMenuAds,
                          color: Colors.blue,
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => UserMyAdvertisementsPage()));
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
                            label: l10n.profileMenuAppData,
                            color: Colors.blue,
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => AdminHubPage()));
                            },
                          ),
                          _buildMenuButton(
                            icon: Icons.emoji_events,
                            label: l10n.profileMenuChallenge,
                            color: primaryYellow,
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => ChallengeDashboardPage()));
                            },
                          ),
                          _buildMenuButton(
                            icon: Icons.business,
                            label: l10n.profileMenuContacts,
                            color: Colors.purple,
                            onTap: () {
                              Navigator.pushNamed(context, '/list_conversation_user_entreprise');
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: 15),
                    ],
                    if (authProvider.loginUserData.role == UserRole.ADM.name) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMenuButton(
                            icon: Icons.add_card_outlined,
                            label: l10n.profileMenuPub,
                            color: Colors.deepPurple,
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => AdvertisementManagementPage()));
                            },
                          ),        _buildMenuButton(
                            icon: Icons.email,
                            label: l10n.profileMenuEmailing,
                            color: Colors.blue,
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => AdminEmailScreen()));
                            },
                          ),
                          _buildMenuButton(
                            icon: MaterialIcons.sports_soccer,
                            label: l10n.profileMenuPronostic,
                            color: Colors.green,
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => AdminPronosticsPage()));
                            },
                          ),

                        ],
                      ),
                      SizedBox(height: 15),

                    ],     if (authProvider.loginUserData.role == UserRole.ADM.name) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMenuButton(
                            icon: Fontisto.tinder,
                            label: l10n.profileMenuAfrolove,
                            color: Colors.red,
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => AdminDatingProfilesPage()));
                            },
                          ),

                        ],
                      ),
                      SizedBox(height: 15),

                    ],

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
          color: _colors.surfaceVariant,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: _colors.border,
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
                color: _colors.textPrimary,
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
