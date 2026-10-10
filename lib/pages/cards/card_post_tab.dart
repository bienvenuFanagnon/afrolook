import 'package:flutter/material.dart';

import '../../l10n/tr.dart';
import '../../models/model_data.dart';
import '../../theme/app_colors.dart';
import 'card_canvas.dart';
import 'card_entry.dart';
import 'card_models.dart';
import 'card_tutorial_page.dart';

/// Onglet « Carte » de la page de création de post : on crée une carte (texte, images, style) et on la publie dans la
/// foulée. La publication passe par l'écran des posts image, donc avec exactement les mêmes règles (délai entre deux
/// posts, nombre de caractères, pays, hashtags…).
class UserPostCardTab extends StatelessWidget {
  const UserPostCardTab({super.key, this.canal, this.defiPostId});
  final Canal? canal;
  final String? defiPostId;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      child: Column(children: [
        SizedBox(
          height: 250,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Flexible(child: _tilt(-0.05, CardCanvas(source: CardDemo.post(), spec: CardSpec(style: CardStyleId.wax)))),
            const SizedBox(width: 12),
            Flexible(child: _tilt(0.04, CardCanvas(source: CardDemo.post(images: const [], text: 'Ton texte, mis en forme comme une affiche ✨'), spec: CardSpec(style: CardStyleId.neon)))),
          ]),
        ),
        const SizedBox(height: 18),
        Text(context.tr('Crée une carte Afrolook'), textAlign: TextAlign.center, style: TextStyle(color: c.textPrimary, fontSize: 21, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(
          context.tr('Écris ton texte, ajoute jusqu\'à 4 images, choisis un style africain unique et publie directement ta carte. Aucune image n\'est coupée.'),
          textAlign: TextAlign.center,
          style: TextStyle(color: c.textSecondary, fontSize: 14.5, height: 1.45),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28))),
            onPressed: () => CardEntry.openCompose(context, canal: canal, defiPostId: defiPostId),
            icon: const Icon(Icons.auto_awesome_rounded),
            label: Text(context.tr('Créer ma carte'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28))),
            onPressed: () => CardEntry.openCompose(context, canal: canal, defiPostId: defiPostId, askLink: true),
            icon: const Icon(Icons.link_rounded),
            label: Text(context.tr('Carte à partir d\'un lien'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
          ),
        ),
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CardTutorialPage())),
          icon: const Icon(Icons.play_circle_outline_rounded, size: 20),
          label: Text(context.tr('Voir comment ça marche')),
        ),
        const SizedBox(height: 4),
        Text(
          context.tr('Les mêmes règles que pour un post : délai entre deux publications, longueur de la légende, pays.'),
          textAlign: TextAlign.center,
          style: TextStyle(color: c.textSecondary, fontSize: 12),
        ),
      ]),
    );
  }

  Widget _tilt(double angle, Widget card) => Transform.rotate(angle: angle, child: FittedBox(fit: BoxFit.contain, child: card));
}
