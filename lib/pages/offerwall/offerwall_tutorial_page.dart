import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/app_colors.dart';
import '../intro/tutos/tuto_catalog.dart';
import '../intro/tutos/tuto_scene_card.dart';

/// Tutoriel animé (avec sons) des tâches rémunérées : « Travaille dans Afrolook et sois payé ». Montré automatiquement à la première arrivée sur la page
/// « Travaille et gagne de l'argent », puis relancé à volonté par le bouton du coin de cette page. Même moteur que les autres tutoriels (scène « taches »
/// de tuto_catalog.dart). Voir docs/OFFERWALL_TACHES.md §18.
class OfferwallTutorialPage extends StatelessWidget {
  const OfferwallTutorialPage({super.key});

  static const _kSeen = 'offerwall_tuto_seen_v1';

  /// La personne a-t-elle déjà vu ce tutoriel sur cet appareil ?
  static Future<bool> alreadySeen() async {
    try {
      return (await SharedPreferences.getInstance()).getBool(_kSeen) ?? false;
    } catch (_) {
      return true; // en cas de doute, ne pas imposer le tutoriel
    }
  }

  static Future<void> markSeen() async {
    try {
      await (await SharedPreferences.getInstance()).setBool(_kSeen, true);
    } catch (_) {}
  }

  /// Ouvre le tutoriel (et le compte comme vu).
  static Future<void> open(BuildContext context) {
    markSeen();
    return Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OfferwallTutorialPage()));
  }

  @override
  Widget build(BuildContext context) {
    final scene = kTutoScenes.firstWhere((s) => s.id == 'taches');
    return Scaffold(
      backgroundColor: AppColors.of(context).background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: TutoSceneCard(
            scene: scene,
            sound: true,
            fullScreen: true,
            onClose: () => Navigator.of(context).maybePop(),
            // le bouton du bas referme simplement le tutoriel : la personne est déjà sur la page des tâches
            onActionOverride: () => Navigator.of(context).maybePop(),
            actionLabelOverride: 'J\'ai compris, voir les tâches', // clé française : la carte la traduit elle-même
          ),
        ),
      ),
    );
  }
}
