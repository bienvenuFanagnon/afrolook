import 'package:flutter/material.dart';

/// Page retirée : voir le journal de migration (aucune donnée Firebase n'est plus lue ici). Le fichier peut être supprimé.
class AfrolookGroupMigrationPage extends StatelessWidget {
  const AfrolookGroupMigrationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Groupe Afrolook')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Cet outil de migration n’est plus utilisé avec la nouvelle API.', textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
