import 'package:flutter/material.dart';

/// Page retirée de cette version (plus aucune lecture Firebase). Le fichier pourra être supprimé ou réécrit quand l'API aura la fonction.
class TeamAdminPage extends StatelessWidget {
  const TeamAdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Équipe')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('La gestion de l’équipe de projet est mise de côté dans la nouvelle version.', textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
