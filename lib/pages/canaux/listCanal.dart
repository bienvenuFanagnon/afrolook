import 'package:afrotok/models/model_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/userProvider.dart';
import '../../providers/postProvider.dart';
import 'detailsCanal.dart';
import 'newCanal.dart';

class CanalListPage extends StatefulWidget {
  final bool isUserCanals;

  CanalListPage({required this.isUserCanals});

  @override
  _CanalListPageState createState() => _CanalListPageState();
}

class _CanalListPageState extends State<CanalListPage> {
  List<Canal> canals = [];
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  late UserProvider userProvider =
  Provider.of<UserProvider>(context, listen: false);
  final List<String> noms = ['Alice', 'Bob', 'Charlie'];
  late PostProvider postProvider =
  Provider.of<PostProvider>(context, listen: false);


  List<Canal> canaux = []; // Liste locale pour stocker les notifications
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  bool isFollowing = false;

  @override
  void initState() {
    super.initState();
    // checkIfFollowing();
  }

  void checkIfFollowing(Canal canal) {
    if (canal.usersSuiviId!.contains(authProvider.loginUserData.id)) {
      setState(() {
        isFollowing = true;
      });
    }
  }

  Future<void> suivreCanal(Canal canal) async {
    final String userId = authProvider.loginUserData.id!;

    // Vérifier si l'utilisateur suit déjà le canal
    if (canal.usersSuiviId!.contains(userId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Vous suivez déjà ce canal.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.orange),
          ),
        ),
      );
      return;
    }

    // Ajouter l'utilisateur à la liste des abonnés
    canal.usersSuiviId!.add(userId);
    await firestore.collection('Canaux').doc(canal.id).update({
      'usersSuiviId': canal.usersSuiviId,
    });

    setState(() {
      isFollowing = true;
    });

    // Création de la notification
    NotificationData notif = NotificationData(
      id: firestore.collection('Notifications').doc().id,
      titre: "Canal 📺",
      media_url: authProvider.loginUserData.imageUrl,
      type: NotificationType.ACCEPTINVITATION.name,
      description:
      "@${authProvider.loginUserData.pseudo!} suit votre canal #${canal.titre!} 📺!",
      users_id_view: [],
      user_id: userId,
      receiver_id: canal.userId!,
      post_id: "",
      post_data_type: "",
      updatedAt: DateTime.now().microsecondsSinceEpoch,
      createdAt: DateTime.now().microsecondsSinceEpoch,
      status: PostStatus.VALIDE.name,
    );

    await firestore.collection('Notifications').doc(notif.id).set(notif.toJson());

    // Envoi de la notification
    await authProvider.sendNotification(
      userIds: [canal.user!.oneIgnalUserid!],
      smallImage: canal.urlImage!,
      send_user_id: userId,
      recever_user_id: canal.userId!,
      message:
      "📢📺 @${authProvider.loginUserData.pseudo!} suit votre canal #${canal.titre!} 📺!",
      type_notif: NotificationType.ACCEPTINVITATION.name,
      post_id: "",
      post_type: "",
      chat_id: "",
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Vous suivez maintenant ce canal.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.green),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    late UserAuthProvider authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    canaux = [];
    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(color: Colors.white),
        title: Text('Liste des Canaux',style: TextStyle(color: Colors.white),),
        actions: [
          IconButton(onPressed: () {
            setState(() {
              
            });
          }, icon: Icon(Icons.refresh))
        ],
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(8),
        child: StreamBuilder<List<Canal>>(
    stream: postProvider.getCanaux(),
    builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
    return Center(child: CircularProgressIndicator());
    }

    if (snapshot.hasError) {
    return Center(child: Text("Erreur de chargement", style: TextStyle(color: Colors.red)));
    }

    if (!snapshot.hasData || snapshot.data!.isEmpty) {
    return Center(child: Text("Aucun canal disponible."));
    }

    List<Canal> canaux = snapshot.data!;

    return ListView.builder(
    itemCount: canaux.length,
    itemBuilder: (context, index) {
    Canal canal = canaux[index];

                return Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(5)),
                      color: Colors.green.shade100,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: ListTile(
                        title: Row(
                          children: [
                            SizedBox(
                              width: 120,
                              child: Text("#${canal.titre!}", style: TextStyle(color: Colors.green,fontWeight: FontWeight.w900)),
                            ),
                            SizedBox(width: 5),
                            Visibility(
                              visible: canal.isVerify == null || canal.isVerify == false ? false : true,
                              child: Card(
                                child: const Icon(
                                  Icons.verified,
                                  color: Colors.blue,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Abonnés: ${canal.usersSuiviId!.length}'),
                          ],
                        ),
                        leading: CircleAvatar(
                          radius: 50,
                          backgroundImage: canal.urlImage != null
                              ? NetworkImage(canal.urlImage!)
                              : AssetImage('assets/default_profile.png') as ImageProvider,
                        ),
                        trailing: canal.usersSuiviId!.contains(authProvider.loginUserData.id)
                            ? null
                            : TextButton(
                          onPressed: () {
                            suivreCanal(canal);
                          },
                          style: ElevatedButton.styleFrom(

                            backgroundColor: Colors.green, // Background color
                            // onPrimary: Colors.white, // Text color
                          ),
                          child: Text('Suivre', style: TextStyle(color: Colors.white)),
                        ),
                        onTap: () {
                          // Naviguer vers la page de détails du canal
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CanalDetails(canal: canal),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Naviguer vers la page de création de canal
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => NewCanal()),
          );
        },
        child: Icon(Icons.add,color: Colors.white,),
        backgroundColor: Colors.green,
      ),
    );
  }
}