import 'package:flutter/material.dart';

/// Page retirée de cette version (plus aucune lecture Firebase). Le fichier pourra être supprimé ou réécrit quand l'API aura la fonction.
class NewAppInfo extends StatelessWidget {
  const NewAppInfo({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle information')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Cet outil n’est plus utilisé avec la nouvelle API.', textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
