import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Création d'une publicité / boost d'une publication.
/// En attente de la route serveur « boost payé en pièces » (création de l'annonce + débit dans la même transaction) :
/// aucune pièce n'est débitée tant qu'elle n'existe pas. Voir connaissances/lacunes_api_compte_boosts.md.
class UserCreateAdvertisementPage extends StatelessWidget {
  final Post? existingPost; // null = nouvelle publicité ; non-null = booster une publication existante

  const UserCreateAdvertisementPage({Key? key, this.existingPost}) : super(key: key);

  @override
  Widget build(BuildContext context) => const BoostSoonView(titre: 'Publicité et boost');
}

/// Écran « bientôt disponible » commun aux pages de boost (publication, profil, canal, groupe).
class BoostSoonView extends StatelessWidget {
  final String titre;
  const BoostSoonView({Key? key, required this.titre}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: Text(titre), backgroundColor: c.surface, foregroundColor: c.textPrimary, elevation: 0),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.rocket_launch_outlined, size: 56, color: c.textSecondary),
            const SizedBox(height: 16),
            Text('Bientôt disponible', style: TextStyle(color: c.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text(
              'Le boost avec tes pièces est en cours de mise à jour. Tes pièces ne sont pas débitées. Reviens très vite !',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 20),
            OutlinedButton(onPressed: () => Navigator.maybePop(context), child: const Text('Retour')),
          ]),
        ),
      ),
    );
  }
}
