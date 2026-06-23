import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../../providers/authProvider.dart';

import '../../../providers/userProvider.dart';

import '../../providers/postProvider.dart';

import '../../theme/app_colors.dart';

import '../../l10n/app_localizations.dart';

import 'detailsCanal.dart';

import 'newCanal.dart';

class CanalListPageByUser extends StatefulWidget {
  @override
  _CanalListPageByUserState createState() => _CanalListPageByUserState();
}

class _CanalListPageByUserState extends State<CanalListPageByUser> {
  List<Canal> allCanaux = [];
  List<Canal> createdCanaux = [];
  List<Canal> adminCanaux = [];
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';

  late AppColors _colors;

  @override
  void initState() {
    super.initState();
    _loadCanaux();
  }

  Future<void> _loadCanaux() async {
    setState(() {
      isLoading = true;
      hasError = false;
      allCanaux.clear();
      createdCanaux.clear();
      adminCanaux.clear();
    });

    try {
      final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
      final postProvider = Provider.of<PostProvider>(context, listen: false);
      final userId = authProvider.loginUserData.id!;

      final stream = postProvider.getAllCanauxForUser(userId);

      await for (Canal canal in stream) {
        if (!allCanaux.any((c) => c.id == canal.id)) {
          allCanaux.add(canal);

          if (canal.userId == userId) {
            createdCanaux.add(canal);
          } else {
            adminCanaux.add(canal);
          }

          setState(() {});
        }
      }

      setState(() {
        isLoading = false;
      });

    } catch (e) {
      printVm("Erreur chargement canaux: $e");
      setState(() {
        isLoading = false;
        hasError = true;
        errorMessage = 'Erreur de chargement: $e';
      });
    }
  }

  Future<void> _suivreCanal(Canal canal, BuildContext context) async {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final userId = authProvider.loginUserData.id!;
    final l10n = AppLocalizations.of(context);

    if (!canal.usersSuiviId!.contains(userId)) {
      try {
        canal.usersSuiviId!.add(userId);

        await firestore.collection('Canaux').doc(canal.id).update({
          'usersSuiviId': canal.usersSuiviId,
          'updatedAt': DateTime.now().microsecondsSinceEpoch,
        });

        final notif = NotificationData(
          id: firestore.collection('Notifications').doc().id,
          titre: "Canal 📺",
          media_url: authProvider.loginUserData.imageUrl,
          type: "FOLLOW_CANAL",
          description: "@${authProvider.loginUserData.pseudo!} suit votre canal #${canal.titre!}",
          user_id: userId,
          receiver_id: canal.userId,
          createdAt: DateTime.now().microsecondsSinceEpoch,
          updatedAt: DateTime.now().microsecondsSinceEpoch,
          status: "VALIDE",
        );

        await firestore.collection('Notifications').doc(notif.id).set(notif.toJson());

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ ${l10n.canalNowFollowing}!',
              style: TextStyle(color: _colors.onPrimary),
            ),
            backgroundColor: _colors.primary,
          ),
        );

        setState(() {});
      } catch (e) {
        printVm("Erreur suivre canal: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erreur lors du suivi',
              style: TextStyle(color: _colors.onPrimary),
            ),
            backgroundColor: _colors.danger,
          ),
        );
      }
    }
  }

  Widget _buildCanalCard(Canal canal, BuildContext context, {bool isAdminCard = false}) {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final isOwner = canal.userId == authProvider.loginUserData.id;
    final isFollowing = canal.usersSuiviId?.contains(authProvider.loginUserData.id) == true;
    final isAdmin = canal.adminIds?.contains(authProvider.loginUserData.id) == true && !isOwner;
    final l10n = AppLocalizations.of(context);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _colors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CanalDetails(canal: canal),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar du canal avec badge
                Stack(
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: isOwner
                              ? [_colors.primary, _colors.accent]
                              : isAdminCard
                              ? [_colors.warning, _colors.warning.withOpacity(0.6)]
                              : [_colors.info, _colors.info.withOpacity(0.6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 32,
                        backgroundColor: _colors.surface,
                        backgroundImage: canal.urlImage != null && canal.urlImage!.isNotEmpty
                            ? NetworkImage(canal.urlImage!)
                            : null,
                        child: canal.urlImage == null || canal.urlImage!.isEmpty
                            ? Icon(
                          isOwner ? Icons.star : Icons.admin_panel_settings,
                          size: 30,
                          color: isOwner ? _colors.primary : _colors.warning,
                        )
                            : null,
                      ),
                    ),
                    if (canal.isVerify == true)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: _colors.surface,
                            shape: BoxShape.circle,
                            border: Border.all(color: _colors.info, width: 1.5),
                          ),
                          child: Icon(
                            Icons.verified,
                            size: 14,
                            color: _colors.info,
                          ),
                        ),
                      ),
                    if (isOwner || isAdmin)
                      Positioned(
                        top: 0,
                        left: 0,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isOwner ? _colors.primary : _colors.warning,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            isOwner ? l10n.canalProprioLabel : l10n.canalAdminLabel,
                            style: TextStyle(
                              color: _colors.onPrimary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                SizedBox(width: 16),

                // Infos du canal
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              "#${(canal.titre != null && canal.titre!.length > 12) ? '${canal.titre!.substring(0, 12)}...' : canal.titre ?? 'Sans nom'}",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _colors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 4),

                      if (isAdminCard && canal.user != null)
                        Text(
                          'Créé par: ${canal.user!.pseudo ?? l10n.canalUnknown}',
                          style: TextStyle(
                            fontSize: 12,
                            color: _colors.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                      if (canal.description != null && canal.description!.isNotEmpty)
                        Text(
                          canal.description!,
                          style: TextStyle(
                            fontSize: 14,
                            color: _colors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                      SizedBox(height: 8),

                      Row(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.people, size: 16, color: _colors.accent),
                              SizedBox(width: 4),
                              Text(
                                "${canal.usersSuiviId?.length ?? 0}",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _colors.textPrimary,
                                ),
                              ),
                            ],
                          ),

                          SizedBox(width: 16),

                          Row(
                            children: [
                              Icon(Icons.post_add, size: 16, color: _colors.primary),
                              SizedBox(width: 4),
                              Text(
                                "${canal.publication ?? 0}",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _colors.textPrimary,
                                ),
                              ),
                            ],
                          ),

                          Spacer(),

                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: canal.isPrivate == true
                                  ? _colors.accent.withOpacity(0.2)
                                  : _colors.primary.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: canal.isPrivate == true ? _colors.accent : _colors.primary,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  canal.isPrivate == true ? Icons.lock : Icons.public,
                                  size: 12,
                                  color: canal.isPrivate == true ? _colors.accent : _colors.primary,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  canal.isPrivate == true ? l10n.canalPrivate : l10n.canalPublic,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: canal.isPrivate == true ? _colors.accent : _colors.primary,
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

                if (!isOwner && !isFollowing)
                  Container(
                    margin: EdgeInsets.only(left: 8),
                    child: ElevatedButton(
                      onPressed: () => _suivreCanal(canal, context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _colors.primary,
                        foregroundColor: _colors.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: Text(
                        l10n.canalFollow,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
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

  Widget _buildSectionHeader({required String title, required int count, required Color color}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _colors.textPrimary,
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: _colors.onPrimary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySection({required String message, required IconData icon, Color? color}) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _colors.border),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 50,
            color: color ?? _colors.textSecondary,
          ),
          SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(_colors.primary),
          ),
          SizedBox(height: 16),
          Text(
            l10n.canalLoading,
            style: TextStyle(color: _colors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 60, color: _colors.danger),
          SizedBox(height: 16),
          Text(
            'Erreur de chargement',
            style: TextStyle(
              fontSize: 18,
              color: _colors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            errorMessage,
            textAlign: TextAlign.center,
            style: TextStyle(color: _colors.textSecondary),
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadCanaux,
            style: ElevatedButton.styleFrom(
              backgroundColor: _colors.primary,
              foregroundColor: _colors.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: Text('Réessayer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyAll() {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.group_off, size: 80, color: _colors.textSecondary),
          SizedBox(height: 16),
          Text(
            l10n.canalNone,
            style: TextStyle(fontSize: 18, color: _colors.textSecondary, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8),
          Text(
            l10n.canalCreateFirstOne,
            style: TextStyle(color: _colors.textSecondary),
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => NewCanal()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _colors.primary,
              foregroundColor: _colors.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: Text(
              l10n.canalCreate,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final hasCreatedCanals = createdCanaux.isNotEmpty;
    final hasAdminCanals = adminCanaux.isNotEmpty;
    final isEmpty = !hasCreatedCanals && !hasAdminCanals;

    return Scaffold(
      backgroundColor: _colors.background,
      appBar: AppBar(
        title: Text(
          l10n.canalMyChannels,
          style: TextStyle(color: _colors.onPrimary, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        backgroundColor: _colors.primary,
        iconTheme: IconThemeData(color: _colors.onPrimary),
        actions: [
          IconButton(
            onPressed: _loadCanaux,
            icon: Icon(Icons.refresh, color: _colors.onPrimary),
            tooltip: 'Rafraîchir',
          ),
        ],
      ),
      body: isLoading
          ? _buildLoading()
          : hasError
          ? _buildError()
          : isEmpty
          ? _buildEmptyAll()
          : RefreshIndicator(
        onRefresh: _loadCanaux,
        color: _colors.primary,
        child: ListView(
          padding: EdgeInsets.only(bottom: 80),
          children: [
            if (hasCreatedCanals) ...[
              _buildSectionHeader(
                title: l10n.canalCreatedBy,
                count: createdCanaux.length,
                color: _colors.primary,
              ),
              ...createdCanaux.map((canal) => _buildCanalCard(canal, context, isAdminCard: false)).toList(),
              SizedBox(height: 20),
            ] else ...[
              _buildSectionHeader(title: l10n.canalCreatedBy, count: 0, color: _colors.primary),
              _buildEmptySection(
                message: l10n.canalNoneCreated,
                icon: Icons.group_off,
                color: _colors.primary.withOpacity(0.5),
              ),
            ],

            if (hasAdminCanals) ...[
              _buildSectionHeader(
                title: l10n.canalAdminOf,
                count: adminCanaux.length,
                color: _colors.warning,
              ),
              ...adminCanaux.map((canal) => _buildCanalCard(canal, context, isAdminCard: true)).toList(),
            ] else ...[
              _buildSectionHeader(title: l10n.canalAdminOf, count: 0, color: _colors.warning),
              _buildEmptySection(
                message: l10n.canalNoneManaged,
                icon: Icons.admin_panel_settings_outlined,
                color: _colors.warning.withOpacity(0.5),
              ),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => NewCanal()));
        },
        backgroundColor: _colors.primary,
        foregroundColor: _colors.onPrimary,
        child: Icon(Icons.add, size: 28),
        shape: CircleBorder(),
      ),
    );
  }
}
