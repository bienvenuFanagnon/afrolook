import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../models/model_data.dart';
import '../../../../providers/authProvider.dart';
import '../repository.dart';

class MyStoriesPage extends StatefulWidget {
  final List<WhatsappStory> stories;
  final UserData user;

  MyStoriesPage({required this.stories, required this.user});

  @override
  State<MyStoriesPage> createState() => _MyStoriesPageState();
}

class _MyStoriesPageState extends State<MyStoriesPage> {
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldMessengerKey,
      appBar: AppBar(
        title: Text('Mes Chroniques', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
      ),
      body: PageView.builder(
        itemCount: widget.stories.length,
        itemBuilder: (context, index) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.stories[index].mediaType == MediaType.image)
                  Image.network(widget.stories[index].media!)
                else
                  Text(
                    widget.stories[index].caption!,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                SizedBox(height: 20),
                Text('Vues: ${widget.stories[index].nbrVues}'),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    _showDeleteDialog(context, widget.stories[index], index);
                  },
                  child: Text('Supprimer la chronique', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WhatsappStory story, int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Supprimer la story'),
          content: Text('Voulez-vous vraiment supprimer cette story ?'),
          actions: [
            TextButton(
              child: Text('Annuler', style: TextStyle(color: Colors.green)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Supprimer', style: TextStyle(color: Colors.white)),
              style: TextButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                bool success = await authProvider.supprimerStories(authProvider.loginUserData, index);
                Navigator.of(context).pop();
                scaffoldMessengerKey.currentState?.showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Story supprimée avec succès' : 'Erreur lors de la suppression de la story'),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
                if (success) {
                  Navigator.pop(context);
                }
              },
            ),
          ],
        );
      },
    );
  }
}