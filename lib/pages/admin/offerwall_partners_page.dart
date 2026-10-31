import 'package:flutter/material.dart';

/// Page retirée : voir le journal de migration (aucune donnée Firebase n'est plus lue ici). Le fichier peut être supprimé.
class OfferwallPartnersPage extends StatelessWidget {
  const OfferwallPartnersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tâches : partenaires')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Le mur de tâches des partenaires est abandonné : cette page n’existe plus.', textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
