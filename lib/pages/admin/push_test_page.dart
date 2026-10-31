import 'package:flutter/material.dart';

/// Page retirée : voir le journal de migration (aucune donnée Firebase n'est plus lue ici). Le fichier peut être supprimé.
class PushTestPage extends StatelessWidget {
  const PushTestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Essai notifications')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Les essais de notifications se feront depuis le serveur dans la nouvelle API.', textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
