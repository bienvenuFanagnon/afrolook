import 'package:flutter/material.dart';

/// Page retirée : voir le journal de migration (aucune donnée Firebase n'est plus lue ici). Le fichier peut être supprimé.
class ReadMeterPage extends StatelessWidget {
  const ReadMeterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mesure des lectures')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('La mesure des lectures n’a plus d’objet avec la nouvelle API.', textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
