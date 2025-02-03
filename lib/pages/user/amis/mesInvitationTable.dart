import 'dart:async';
import 'package:afrotok/services/api.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:provider/provider.dart';

import '../../../constant/constColors.dart';
import '../../../models/model_data.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/userProvider.dart';
import '../../user/detailsOtherUser.dart';

class MesInvitations extends StatefulWidget {
  const MesInvitations({super.key});

  @override
  State<MesInvitations> createState() => _MesInvitationsState();
}

class _MesInvitationsState extends State<MesInvitations> {
  late UserAuthProvider authProvider;
  late UserProvider userProvider;
  final Map<String, bool> inviteTapMap = {};
  final Map<String, bool> refusInviteTapMap = {};

  @override
  void initState() {
    super.initState();
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    userProvider = Provider.of<UserProvider>(context, listen: false);
  }

  String formatNumber(int number) {
    return number >= 1000 ? '${(number / 1000).toStringAsFixed(1)}k' : number.toString();
  }

  void _showUserDetailsModalDialog(UserData user, double w, double h) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(content: DetailsOtherUser(user: user, w: w, h: h)),
    );
  }

  Widget invitationData(Invitation invitation) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    bool inviteTap = inviteTapMap[invitation.inviteUser!.id] ?? false;
    bool refusInviteTap = refusInviteTapMap[invitation.inviteUser!.id] ?? false;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: <Widget>[
          GestureDetector(
            onTap: () => _showUserDetailsModalDialog(invitation.inviteUser!, width, height),
            child: Row(
              children: <Widget>[
                CircleAvatar(
                  backgroundImage: NetworkImage(invitation.inviteUser!.imageUrl!),
                  maxRadius: 30,
                  onBackgroundImageError: (_, __) => const AssetImage('assets/icon/user-removebg-preview.png'),
                ),
                const SizedBox(width: 16),
                Row(
                  spacing: 10,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text("@${invitation.inviteUser!.pseudo!}".toLowerCase(), style: const TextStyle(fontSize: 16)),
                        const SizedBox(height: 6),
                        Text('${formatNumber(invitation.inviteUser!.abonnes!)} abonné(s)',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                      ],
                    ),
                    Visibility(
                      visible: invitation.inviteUser!.isVerify!||invitation.inviteUser!.isVerify==false!?false:true,
                      child: Card(
                        child: const Icon(
                          Icons.verified,
                          color: Colors.green,
                          size: 17,
                        ),
                      ),
                    )
                  ],
                ),
              ],
            ),
          ),
          Row(
            children: [
              TextButton(
                onPressed: inviteTap ? null : () async {
                  setState(() => inviteTapMap[invitation.inviteUser!.id!] = true);
                  bool success = await userProvider.acceptInvitation(invitation);
                  if (success) {
                    await _handleAcceptedInvitation(invitation);
                  } else {
                    _showSnackBar("Erreur lors de l'acceptation.", Colors.red);
                  }
                  setState(() => inviteTapMap[invitation.inviteUser!.id!] = false);
                },
                child: inviteTap
                    ? LoadingAnimationWidget.flickr(size: 15, leftDotColor: Colors.green, rightDotColor: Colors.black)
                    : const Text('Accepter', style: TextStyle(fontSize: 12, color: Colors.blue)),
              ),
              TextButton(
                onPressed: refusInviteTap ? null : () async {
                  setState(() => refusInviteTapMap[invitation.inviteUser!.id!] = true);
                  bool success = await userProvider.refuserInvitation(invitation);
                  if (success) {
                    _showSnackBar("Invitation refusée!", Colors.green);
                  } else {
                    _showSnackBar("Erreur.", Colors.red);
                  }
                  setState(() => refusInviteTapMap[invitation.inviteUser!.id!] = false);
                },
                child: refusInviteTap
                    ? LoadingAnimationWidget.flickr(size: 15, leftDotColor: Colors.green, rightDotColor: Colors.black)
                    : const Text('Refuser', style: TextStyle(fontSize: 12, color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleAcceptedInvitation(Invitation invitation) async {
    authProvider.loginUserData.friendsIds!.add(invitation.inviteUser!.id!);
    await userProvider.updateUser(authProvider.loginUserData);

    await authProvider.sendNotification(
      userIds: [invitation.inviteUser!.oneIgnalUserid!],
      smallImage: authProvider.loginUserData.imageUrl!,
      send_user_id: authProvider.loginUserData.id!,
      recever_user_id: invitation.inviteUser!.id!,
      message: "📢 @${authProvider.loginUserData.pseudo!} a accepté(e) votre invitation !",
      type_notif: NotificationType.ACCEPTINVITATION.name,
      post_id: "",
      post_type: "",
      chat_id: "",
    );

    await userProvider.getUsersProfile(authProvider.loginUserData.id!, context);
    _showSnackBar("Invitation acceptée!", Colors.green);
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Center(child: Text(message, style: TextStyle(color: color))),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      margin: EdgeInsets.only(bottom: MediaQuery.of(context).size.height - 100, right: 20, left: 20),
    ));
  }

  Stream<List<Invitation>> getData() async* {
    List<Invitation> invitations = [];
    var invitationsStream = FirebaseFirestore.instance
        .collection('Invitations')
        .where('receiver_id', isEqualTo: authProvider.loginUserData.id!)
        .where('status', isEqualTo: InvitationStatus.ENCOURS.name)
        .snapshots();

    await for (var invitationsSnapshot in invitationsStream) {
      invitations = invitationsSnapshot.docs.map((doc) => Invitation.fromJson(doc.data())).toList();
      yield invitations;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: StreamBuilder<List<Invitation>>(
        stream: getData(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return ListView.builder(
              shrinkWrap: true,
              itemCount: snapshot.data!.length,
              itemBuilder: (_, index) => invitationData(snapshot.data![index]),
            );
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}
