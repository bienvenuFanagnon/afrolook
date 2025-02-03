import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/model_data.dart';
import '../../providers/userProvider.dart';
import '../component/showUserDetails.dart';

class ChannelFollowersPage extends StatefulWidget {
  final List<String> userIds;

  ChannelFollowersPage({required this.userIds});

  @override
  State<ChannelFollowersPage> createState() => _ChannelFollowersPageState();
}

class _ChannelFollowersPageState extends State<ChannelFollowersPage> {


  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(
        title: Text('Abonnés du Canal'),
      ),
      body: FutureBuilder<List<UserData>>(
        future: userProvider.getChallengeUsers(widget.userIds),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Erreur de chargement des données'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('Aucun abonné trouvé'));
          } else {
            List<UserData> list = snapshot.data!;

            return ListView.builder(
              itemCount: list.length,
              itemBuilder: (context, index) {
                final user = list[index];
                return ListTile(
                  onTap: () {
                    showUserDetailsModalDialog(user, width, height,context);
                  },
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(user.imageUrl ?? ''),
                  ),
                  title: Text(
                    "@${user.pseudo ?? 'Utilisateur'}",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "${user.userAbonnesIds?.length ?? 0} abonné(s)",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}

