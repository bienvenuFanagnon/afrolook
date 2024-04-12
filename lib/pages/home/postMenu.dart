import 'package:flutter/material.dart';

class PostMenu extends StatelessWidget {
  const PostMenu({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      child: ListView(
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('Supprimer'),
            onTap: () {
              // Action à exécuter lors de la suppression du post
            },
          ),
          ListTile(
            leading: const Icon(Icons.flag),
            title: const Text('Signaler'),
            onTap: () {
              // Action à exécuter lors du signalement du post
            },
          ),
        ],
      ),
    );
  }
}
