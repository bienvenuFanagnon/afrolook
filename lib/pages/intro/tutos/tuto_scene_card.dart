import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../l10n/tr.dart';
import 'tuto_catalog.dart';

const _gold = Color(0xFFF5C542);

/// Rotation des scènes : chaque affichage passe à la scène suivante (index mémorisé par « zone »).
class TutoRotation {
  static final Set<String> _shown = {};

  /// Scène suivante pour [zone]. Avec [withLikeAnimation], le créneau 0 (retour `null`)
  /// est réservé à l'animation « like » historique du feed.
  static Future<TutoScene?> next(String zone, {bool publicOnly = false, bool withLikeAnimation = false}) async {
    final scenes = tutoScenesAvailable(publicOnly: publicOnly);
    final slots = scenes.length + (withLikeAnimation ? 1 : 0);
    var i = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      i = ((prefs.getInt('tuto_scene_idx_$zone') ?? -1) + 1) % slots;
      await prefs.setInt('tuto_scene_idx_$zone', i);
    } catch (_) {}
    if (withLikeAnimation) return i == 0 ? null : scenes[i - 1];
    return scenes[i];
  }

  /// Avant la connexion : une scène tous les 2 jours.
  static const _gate = Duration(days: 2);

  static Future<bool> loginSceneDue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getInt('tuto_login_scene_last') ?? 0;
      return DateTime.now().millisecondsSinceEpoch - last >= _gate.inMilliseconds;
    } catch (_) {
      return false;
    }
  }

  static Future<void> markLoginSceneShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('tuto_login_scene_last', DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }
}

/// Carte d'une scène. Lecture animée dans l'ordre : accroche → étapes → chiffre → bouton.
class TutoSceneCard extends StatelessWidget {
  final TutoScene scene;
  final bool fullScreen;
  final VoidCallback? onClose;
  /// Remplace l'action de la scène (ex. avant login : ouvrir l'inscription).
  final VoidCallback? onActionOverride;
  final String? actionLabelOverride;
  final VoidCallback? onSeeAll;

  const TutoSceneCard({
    super.key,
    required this.scene,
    this.fullScreen = false,
    this.onClose,
    this.onActionOverride,
    this.actionLabelOverride,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    final steps = scene.steps;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: _gold.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
            child: Text(context.tr('Le savais-tu ?'),
                style: const TextStyle(color: _gold, fontSize: 12, fontWeight: FontWeight.w800)),
          ),
          const Spacer(),
          if (onClose != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
            ),
        ]),
        const SizedBox(height: 10),
        // 1) Accroche
        Center(child: Text(scene.emoji, style: TextStyle(fontSize: fullScreen ? 56 : 40))
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scale(begin: const Offset(0.92, 0.92), end: const Offset(1.08, 1.08), duration: 900.ms)),
        const SizedBox(height: 8),
        Text(context.tr(scene.title),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: fullScreen ? 26 : 20, fontWeight: FontWeight.w800, height: 1.2))
            .animate().fadeIn(duration: 350.ms).slideY(begin: 0.2),
        const SizedBox(height: 6),
        Text(context.tr(scene.hook),
            textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4))
            .animate().fadeIn(delay: 250.ms, duration: 350.ms),
        const SizedBox(height: 14),
        // 2) Étapes numérotées, apparition l'une après l'autre
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: _gold, shape: BoxShape.circle),
                child: Text('${i + 1}',
                    style: const TextStyle(color: Color(0xFF412402), fontWeight: FontWeight.w900, fontSize: 13)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(context.tr(steps[i]),
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ]).animate().fadeIn(delay: (600 + i * 350).ms, duration: 350.ms).slideX(begin: 0.15),
          ),
        const SizedBox(height: 6),
        // 3) Chiffre clé
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2410),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _gold.withOpacity(0.5)),
          ),
          child: Column(children: [
            Text(context.tr(scene.figure),
                textAlign: TextAlign.center,
                style: const TextStyle(color: _gold, fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(context.tr(scene.figureLabel),
                textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, fontSize: 12)),
          ]),
        ).animate().fadeIn(delay: (600 + steps.length * 350).ms, duration: 400.ms).scale(begin: const Offset(0.9, 0.9)),
        const SizedBox(height: 14),
        // 4) Bouton d'action de la scène
        ElevatedButton(
          onPressed: onActionOverride ?? () => scene.action?.call(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2ECC71),
            foregroundColor: const Color(0xFF06331A),
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Text(context.tr(actionLabelOverride ?? scene.actionLabel),
              style: const TextStyle(fontWeight: FontWeight.w800)),
        )
            .animate(delay: (900 + steps.length * 350).ms, onPlay: (c) => c.repeat(reverse: true))
            .scale(begin: const Offset(1, 1), end: const Offset(1.03, 1.03), duration: 800.ms),
        if (onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
            child: Text(context.tr('Voir tous les tutoriels'), style: const TextStyle(color: Colors.white60)),
          ),
        if (fullScreen) ...[
          const SizedBox(height: 10),
          Text(context.tr('Glisse vers le haut pour continuer'),
              textAlign: TextAlign.center, style: const TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ],
    );

    return Container(
      margin: fullScreen ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      padding: EdgeInsets.fromLTRB(16, fullScreen ? 60 : 14, 16, fullScreen ? 30 : 16),
      decoration: BoxDecoration(
        borderRadius: fullScreen ? null : BorderRadius.circular(22),
        border: fullScreen ? null : Border.all(color: _gold.withOpacity(0.25)),
        gradient: const RadialGradient(
          center: Alignment(-0.8, -0.9),
          radius: 1.3,
          colors: [Color(0x331FAA59), Color(0xFF070B09)],
        ),
      ),
      child: fullScreen ? Center(child: SingleChildScrollView(child: content)) : content,
    );
  }
}

/// Liste de tous les tutoriels, ouvrable depuis les cartes et le menu.
class TutoListPage extends StatelessWidget {
  const TutoListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scenes = tutoScenesAvailable();
    return Scaffold(
      backgroundColor: const Color(0xFF070B09),
      appBar: AppBar(
        backgroundColor: const Color(0xFF070B09),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(context.tr('Tous les tutoriels')),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(14),
        itemCount: scenes.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final s = scenes[i];
          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TutoScenePage(scene: s))),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF111814),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _gold.withOpacity(0.2)),
              ),
              child: Row(children: [
                Text(s.emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${i + 1}. ${context.tr(s.title)}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(context.tr(s.hook), style: const TextStyle(color: Colors.white60, fontSize: 12.5)),
                  ]),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white38),
              ]),
            ),
          );
        },
      ),
    );
  }
}

/// Une scène en plein écran.
class TutoScenePage extends StatelessWidget {
  final TutoScene scene;
  final VoidCallback? onActionOverride;
  final String? actionLabelOverride;
  const TutoScenePage({super.key, required this.scene, this.onActionOverride, this.actionLabelOverride});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF070B09),
        body: SafeArea(
          child: SingleChildScrollView(
            child: TutoSceneCard(
              scene: scene,
              onClose: () => Navigator.of(context).maybePop(),
              onActionOverride: onActionOverride,
              actionLabelOverride: actionLabelOverride,
            ),
          ),
        ),
      );
}

/// Page affichée avant la connexion (une scène tous les 2 jours) : « Passer » ou l'action mènent au login.
class TutoBeforeLoginPage extends StatelessWidget {
  final TutoScene scene;
  final VoidCallback onDone;
  const TutoBeforeLoginPage({super.key, required this.scene, required this.onDone});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF070B09),
        body: SafeArea(
          child: SingleChildScrollView(
            child: TutoSceneCard(
              scene: scene,
              onClose: onDone,
              onActionOverride: onDone,
              actionLabelOverride: 'Me connecter ou créer mon compte',
            ),
          ),
        ),
      );
}
