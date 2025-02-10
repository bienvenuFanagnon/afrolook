import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:provider/provider.dart';

import '../../../models/model_data.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/postProvider.dart';
import '../../component/consoleWidget.dart';
import '../../postDetails.dart';
import '../../socialVideos/video_details.dart';

class PostMonetiserWidget extends StatefulWidget {
  late PostMonetiser post;

  PostMonetiserWidget({required this.post});

  @override
  State<PostMonetiserWidget> createState() => _PostMonetiserWidgetState();
}

class _PostMonetiserWidgetState extends State<PostMonetiserWidget> {
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  late PostProvider postProvider =
  Provider.of<PostProvider>(context, listen: false);

  bool isProcessing=false;

  Future<void> encaisserSolde(BuildContext context, String postMonetiserId, String userId) async {
    if (isProcessing) return; // Empêcher les clics multiples
    isProcessing = true;

    // Attendre 2 secondes avant de commencer
    await Future.delayed(Duration(seconds: 2));

    // Récupérer le PostMonetiser
    DocumentSnapshot postMonetiserSnapshot = await FirebaseFirestore.instance
        .collection('PostsMonetiser')
        .doc(postMonetiserId)
        .get();

    if (!postMonetiserSnapshot.exists) {
      print("PostMonetiser introuvable");
      isProcessing = false;
      return;
    }

    PostMonetiser postMonetiser = PostMonetiser.fromJson(postMonetiserSnapshot.data() as Map<String, dynamic>);
    double montant = postMonetiser.solde! * 25;
    print("PostMonetiser ${postMonetiser.toJson()}");
    print("montant $montant");

    // Vérifier que le solde dépasse 2000
    if (montant < 2000.0) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Solde insuffisant 😕"),
            content: Text("Le solde doit atteindre 2000 FCFA avant de pouvoir être encaissé. Veuillez patienter un peu plus longtemps."),
            actions: <Widget>[
              TextButton(
                child: Text("OK"),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
      isProcessing = false;
      return;
    }

    // Récupérer les données de l'utilisateur
    DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
        .collection('Users')
        .doc(userId)
        .get();

    if (!userSnapshot.exists) {
      print("Utilisateur introuvable");
      isProcessing = false;
      return;
    }

    UserData user = UserData.fromJson(userSnapshot.data() as Map<String, dynamic>);

    // Ajouter le solde de PostMonetiser au votre_solde_contenu de l'utilisateur
    user.votre_solde_contenu = (user.votre_solde_contenu ?? 0.0) + postMonetiser.solde!;

    // Mettre à jour les données de l'utilisateur dans Firestore
    await FirebaseFirestore.instance
        .collection('Users')
        .doc(userId)
        .update({'votre_solde_contenu': user.votre_solde_contenu});

    // Réinitialiser le solde de PostMonetiser
    await FirebaseFirestore.instance
        .collection('PostsMonetiser')
        .doc(postMonetiserId)
        .update({'solde': 0.0});

    // Afficher un message de succès
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Succès 🎉"),
          content: Text("Le solde a été encaissé avec succès et ajouté à votre solde contenu."),
          actions: <Widget>[
            TextButton(
              child: Text("OK"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );

    print("Solde encaissé avec succès.");
    isProcessing = false;
  }  @override
  Widget build(BuildContext context) {
    double montant=widget.post.solde!*25;
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Text('Solde :   ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),

            Text('${montant.toStringAsFixed(2)} FCFA', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green)),

            SizedBox(height: 10),
            Row(
              children: [
                Icon(AntDesign.heart, color: Colors.green),
                SizedBox(width: 5),
                Text(
                  'J\'aime: ${widget.post.users_like_id?.length ?? 0}',
                  style: TextStyle(color: Colors.black),
                ),
              ],
            ),
            SizedBox(height: 5),
            Row(
              children: [
                Icon(Icons.comment, color: Colors.yellow),
                SizedBox(width: 5),
                Text(
                  'Commentaires: ${widget.post.users_comments_id?.length ?? 0}',
                  style: TextStyle(color: Colors.black),
                ),
              ],
            ),
            SizedBox(height: 5),
            Row(
              children: [
                Icon(Icons.share, color: Colors.blue),
                SizedBox(width: 5),
                Text(
                  'Partages: ${widget.post.users_partage_id?.length ?? 0}',
                  style: TextStyle(color: Colors.black),
                ),
              ],
            ),            SizedBox(height: 5),

TextButton(onPressed: () {
  switch (widget.post.post!.dataType!) {
    case "VIDEO":
      postProvider.getPostsVideosById(widget.post.post_id!).then((videos_posts) {
        if(videos_posts.isNotEmpty){

          printVm("video detail ======== : ${videos_posts.first.toJson()}");



          Navigator.push(context, MaterialPageRoute(builder: (context) => OnlyPostVideo(videos: videos_posts,),));

        }
      },);

      break;
    case "IMAGE":
      postProvider.getPostsImagesById(widget.post.post_id!).then((posts) {
        if(posts.isNotEmpty){

          Navigator.push(context, MaterialPageRoute(builder: (context) => DetailsPost(post: posts.first),));

        }

      },);
      break;
    case "TEXT":
      postProvider.getPostsImagesById(widget.post.post_id!).then((posts) {
        if(posts.isNotEmpty){

          Navigator.push(context, MaterialPageRoute(builder: (context) => DetailsPost(post: posts.first),));

        }

      },);
      break;
    default:
    // Handle unknown post type
      break;
  }

}, child: Text('Voir le post',style: TextStyle(color: Colors.green),))  ,
            SizedBox(height: 5),
            ElevatedButton.icon(
              onPressed: isProcessing ? null :() async {
                await encaisserSolde(context, widget.post.id!, widget.post.user_id!);

              },
              icon: Icon(Icons.money, color: Colors.white),
              label: Text('Encaisser',style: TextStyle(color: Colors.white),),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}