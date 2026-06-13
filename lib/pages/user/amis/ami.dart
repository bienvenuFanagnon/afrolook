import 'package:afrotok/pages/user/amis/mesAmis.dart';
import 'package:afrotok/services/api.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:contained_tab_bar_view_with_custom_page_navigator/contained_tab_bar_view_with_custom_page_navigator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:page_transition/page_transition.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import '../../../constant/constColors.dart';
import '../../../constant/logo.dart';
import '../../../constant/sizeText.dart';
import '../../../constant/textCustom.dart';
import '../../../models/model_data.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/userProvider.dart';
import '../../auth/authTest/constants.dart';
import '../../component/consoleWidget.dart';
import 'mesInvitationTable.dart';
import '../../../theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';

class Amis extends StatefulWidget {
  const Amis({super.key});

  @override
  State<Amis> createState() => _ListUserChatsState();
}

class _ListUserChatsState extends State<Amis> {
  late AppColors _colors;
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  late UserProvider userProvider =
  Provider.of<UserProvider>(context, listen: false);

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    _colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: _colors.background,
      appBar: AppBar(
        backgroundColor: _colors.surfaceVariant,
        title: Text(
          l10n.profileFriends,
          style: TextStyle(
            fontSize: SizeText.homeProfileTextSize,
            color: _colors.accent,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Logo(),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _colors.primary,
        onPressed: () {
          Navigator.pushNamed(context, '/add_list_amis');
        },
        child: Icon(FontAwesome.users, color: _colors.background),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.miniEndFloat,
      body: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(height: 20),
            Container(
              width: width,
              height: height * 0.9,
              child: ContainedTabBarView(
                tabs: [
                  Center(
                    child: Container(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 4.0),
                            child: Text(
                              l10n.amisTabFriends,
                              style: TextStyle(
                                fontSize: SizeText.homeProfileTextSize,
                                color: _colors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _colors.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "${userProvider.countFriends}",
                              style: TextStyle(
                                fontSize: 12,
                                color: _colors.background,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 4.0),
                            child: Text(
                              l10n.profileInvites,
                              style: TextStyle(
                                fontSize: SizeText.homeProfileTextSize,
                                color: _colors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _colors.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "${userProvider.countInvitations}",
                              style: TextStyle(
                                fontSize: 12,
                                color: _colors.background,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                tabBarProperties: TabBarProperties(
                  alignment: TabBarAlignment.center,
                  height: 48.0,
                  indicatorColor: _colors.primary,
                  indicatorWeight: 4.0,
                  labelColor: _colors.textPrimary,
                  unselectedLabelColor: _colors.textSecondary,
                  background: Container(
                    decoration: BoxDecoration(
                      color: _colors.background,
                      border: Border(
                        bottom: BorderSide(color: _colors.surfaceVariant, width: 1),
                      ),
                    ),
                  ),
                ),
                views: [
                  MesAmis(context: context),
                  MesInvitations(),
                ],
                onChange: (index) => printVm(index),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ConversationList extends StatefulWidget {
  final String name;
  final String messageText;
  final String imageUrl;
  final String time;
  final bool isMessageRead;
  final int abonnesCount;

  ConversationList({
    required this.name,
    required this.messageText,
    required this.imageUrl,
    required this.time,
    required this.isMessageRead,
    required this.abonnesCount,
  });

  @override
  _ConversationListState createState() => _ConversationListState();
}

class _ConversationListState extends State<ConversationList> {
  late AppColors _colors;

  @override
  Widget build(BuildContext context) {
    _colors = AppColors.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: _colors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            backgroundImage: NetworkImage(widget.imageUrl),
            radius: 28,
            backgroundColor: _colors.background,
          ),
          SizedBox(width: 16),
          Expanded(
            child: Container(
              color: Colors.transparent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    widget.name,
                    style: TextStyle(
                      fontSize: 16,
                      color: _colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.people,
                        size: 14,
                        color: _colors.accent,
                      ),
                      SizedBox(width: 4),
                      Text(
                        '${widget.abonnesCount} abonné(s)',
                        style: TextStyle(
                            fontSize: 13,
                            color: _colors.textSecondary,
                            fontWeight: widget.isMessageRead ? FontWeight.bold : FontWeight.normal
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              // Navigation vers la conversation
            },
            icon: Icon(
              Icons.chat,
              color: _colors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class Invitations extends StatefulWidget {
  final String name;
  final String messageText;
  final String imageUrl;
  final String time;
  final int invitation_id;
  final int user_accepted_id;
  final Invitation userInvitation;
  final bool isMessageRead;
  final GlobalKey<FormState> formKey;
  final BuildContext context;

  Invitations({
    required this.formKey,
    required this.context,
    required this.name,
    required this.messageText,
    required this.time,
    required this.imageUrl,
    required this.isMessageRead,
    required this.invitation_id,
    required this.user_accepted_id,
    required this.userInvitation,
  });

  @override
  _InvitationsState createState() => _InvitationsState();
}

class _InvitationsState extends State<Invitations> {
  late AppColors _colors;
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  late UserProvider userProvider =
  Provider.of<UserProvider>(context, listen: false);
  bool inviteTap = false;

  @override
  Widget build(BuildContext context) {
    _colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: _colors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            backgroundImage: NetworkImage(widget.imageUrl),
            radius: 28,
            backgroundColor: _colors.background,
          ),
          SizedBox(width: 16),
          Expanded(
            child: Container(
              color: Colors.transparent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    widget.name,
                    style: TextStyle(
                      fontSize: 16,
                      color: _colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.people,
                        size: 14,
                        color: _colors.accent,
                      ),
                      SizedBox(width: 4),
                      Text(
                        '${widget.userInvitation.inviteUser!.abonnes!} abonné(s)',
                        style: TextStyle(
                            fontSize: 13,
                            color: _colors.textSecondary,
                            fontWeight: widget.isMessageRead ? FontWeight.bold : FontWeight.normal
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              TextButton(
                onPressed: inviteTap
                    ? null
                    : () async {
                  setState(() {
                    inviteTap = true;
                  });
                  await userProvider.acceptInvitation(widget.userInvitation).then((value) async {
                    if (value) {
                      authProvider.loginUserData.friendsIds!.add(widget.userInvitation.inviteUser!.id!);
                      await userProvider.updateUser(authProvider.loginUserData);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          key: widget.formKey,
                          content: Text(
                            "Invitation acceptée!",
                            style: TextStyle(color: _colors.textPrimary),
                          ),
                          backgroundColor: _colors.primary,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          margin: EdgeInsets.only(
                            bottom: MediaQuery.of(context).size.height - 100,
                            right: 20,
                            left: 20,
                          ),
                        ),
                      );

                      await authProvider.getToken();
                      await userProvider.getUsersProfile(authProvider.loginUserData!.id!, context);
                      setState(() {
                        inviteTap = false;
                      });
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            "Erreur lors de l'acceptation.",
                            style: TextStyle(color: _colors.textPrimary),
                          ),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          margin: EdgeInsets.only(
                            bottom: MediaQuery.of(context).size.height - 100,
                            right: 20,
                            left: 20,
                          ),
                        ),
                      );

                      setState(() {
                        inviteTap = false;
                      });
                    }
                  });
                },
                style: TextButton.styleFrom(
                  backgroundColor: _colors.primary,
                  foregroundColor: _colors.background,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: inviteTap
                    ? Center(
                  child: LoadingAnimationWidget.flickr(
                    size: 15,
                    leftDotColor: Colors.white,
                    rightDotColor: _colors.background,
                  ),
                )
                    : Text(
                  l10n.btnAccept,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ),
              SizedBox(width: 8),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  foregroundColor: _colors.textSecondary,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  l10n.btnRefuse,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}