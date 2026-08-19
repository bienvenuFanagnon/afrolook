import 'package:afrotok/layout/centered_content.dart';
import 'package:afrotok/layout/responsive_layout.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:provider/provider.dart';
import '../../../constant/logo.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/postProvider.dart';
import '../../../providers/userProvider.dart';
import '../../../theme/app_colors.dart';
import '../../admin/admin_dashboard_page.dart';
import '../official_account/request_official_account_page.dart';
import '../../../models/official_account/official_account_enums.dart';
import '../../../models/official_account/official_account_request.dart';
import '../../../services/official_account/official_account_service.dart';
import '../../canaux/listCanauxByUser.dart';
import '../../contenuPayant/profileScreenContent.dart';
import '../../userPosts/favorites_posts.dart';
import '../otherUser/otherUser.dart';
import '../remuneration_home_page.dart';
import '../userAbonnementPage.dart';
import '../userPubs/user_my_advertisements_page.dart';
import '../userPubs/user_profile_boost_page.dart';
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

  /// Demande de compte officiel en cours.
  OfficialAccountRequest? _officialRequest;
  bool _officialRequestLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOfficialRequest());
  }

  Future<void> _loadOfficialRequest() async {
    try {
      final myId = Provider.of<UserAuthProvider>(context, listen: false).loginUserData.id;
      if (myId == null) return;
      final req = await OfficialAccountService.instance.getMyRequest(myId);
      if (mounted) setState(() { _officialRequest = req; _officialRequestLoaded = true; });
    } catch (_) {
      if (mounted) setState(() => _officialRequestLoaded = true);
    }
  }

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
      body: CenteredContent(
        maxWidth: AppLayout.isDesktop(context) ? 800 : AppLayout.maxFeedWidth,
        child: SingleChildScrollView(
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
                        _buildMenuButton(
                          icon: Icons.rocket_launch_outlined,
                          label: 'Booster mon profil',
                          color: const Color(0xFFFFD700),
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (_) => const UserProfileBoostPage(),
                            ));
                          },
                        ),
                        if (authProvider.loginUserData.isCreatorProfileEnabled == true)
                          _buildMenuButton(
                            icon: Icons.storefront_rounded,
                            label: 'Mon Business',
                            color: const Color(0xFFFFD400),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ProfileScreenContenu(
                                    userId: authProvider.loginUserData.id,
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),

                    // Bouton Compte officiel
                    if (_officialRequestLoaded) Builder(builder: (_) {
                      final me = authProvider.loginUserData;
                      if (me.isOfficialAccount) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 15),
                          child: _buildOfficialBadge(me),
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 15),
                        child: _buildOfficialAccountButton(_officialRequest),
                      );
                    }),

                    SizedBox(height: 15),

                    // Tableau de bord admin
                    if (authProvider.loginUserData.role == UserRole.ADM.name) ...[
                      GestureDetector(
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const AdminDashboardPage())),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF534AB7), Color(0xFF185FA5)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.admin_panel_settings_rounded,
                                  color: Colors.white, size: 20),
                              SizedBox(width: 10),
                              Text('Tableau de bord admin',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14)),
                              Spacer(),
                              Icon(Icons.arrow_forward_ios_rounded,
                                  color: Colors.white54, size: 14),
                            ],
                          ),
                        ),
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
      ),
    );
  }

  Widget _buildOfficialAccountButton(OfficialAccountRequest? req) {
    if (req == null) {
      return GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RequestOfficialAccountPage()),
        ).then((_) => _loadOfficialRequest()),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7B2FBE), Color(0xFF4A90D9)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.verified_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'Demander un compte officiel',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    final status = req.status;

    // Cas spécial : informations complémentaires — affiche le message admin complet
    if (status == OfficialAccountStatus.moreInfoNeeded) {
      const fg = Color(0xFFE65100);
      const bg = Color(0xFFFFF3E0);
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: fg.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: fg, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Informations complémentaires requises',
                    style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ],
            ),
            if (req.adminNote?.isNotEmpty == true) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => _showAdminNoteDialog(context, req.adminNote!),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
                  decoration: BoxDecoration(
                    color: fg.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: fg.withOpacity(0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.message_outlined, color: fg, size: 15),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Voir le message de l\'administrateur',
                          style: TextStyle(
                              color: fg, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, color: fg, size: 13),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => RequestOfficialAccountPage(existingRequest: req)),
              ).then((_) => _loadOfficialRequest()),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  color: _colors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.edit_rounded, color: Colors.white, size: 15),
                    SizedBox(width: 8),
                    Text('Mettre à jour ma demande',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final (IconData icon, String label, Color bg, Color fg, bool tappable) = switch (status) {
      OfficialAccountStatus.pending => (
          Icons.hourglass_top_rounded,
          'Demande en cours d\'examen...',
          _colors.surfaceVariant,
          _colors.textSecondary,
          false,
        ),
      OfficialAccountStatus.underReview => (
          Icons.manage_search_rounded,
          'En cours d\'analyse par l\'équipe',
          _colors.surfaceVariant,
          Colors.blue,
          false,
        ),
      OfficialAccountStatus.rejected => (
          Icons.refresh_rounded,
          'Renouveler ma demande',
          _colors.surfaceVariant,
          _colors.textSecondary,
          true,
        ),
      OfficialAccountStatus.suspended => (
          Icons.block_rounded,
          'Compte officiel suspendu',
          _colors.surfaceVariant,
          Colors.red,
          false,
        ),
      _ => (Icons.verified_rounded, '', Colors.transparent, Colors.transparent, false),
    };

    if (label.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: tappable
          ? () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RequestOfficialAccountPage()),
              ).then((_) => _loadOfficialRequest())
          : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _colors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: fg, size: 20),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  void _showAdminNoteDialog(BuildContext context, String note) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE65100).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.info_rounded,
                        color: Color(0xFFE65100), size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Message de l\'administrateur',
                      style: TextStyle(
                          color: _colors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE65100).withOpacity(0.2)),
                ),
                child: Text(
                  note,
                  style: const TextStyle(
                      color: Color(0xFFBF360C), fontSize: 14, height: 1.6),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE65100),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Fermer',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfficialBadge(UserData me) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF7B2FBE)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.verified_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              me.officialName?.isNotEmpty == true ? me.officialName! : 'Compte officiel vérifié',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
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
