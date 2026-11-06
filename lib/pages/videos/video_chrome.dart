import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../l10n/tr.dart';
import '../../theme/app_colors.dart';
import '../../widgets/safe_network_avatar.dart';

/// Pièces de l'interface de la page des vidéos verticales (validé le 06/11/2026) : tout est léger, lisible sur n'importe quel fond
/// (pastille sombre translucide + ombre sur les chiffres) et dessiné avec la même famille d'icônes que la barre de navigation.
const _kShadow = [Shadow(color: Color(0xCC000000), blurRadius: 4, offset: Offset(0, 1))];

/// Bouton rond de la colonne de droite : pastille sombre translucide, icône blanche (ou couleur du thème quand il est actif), chiffre dessous.
class VideoRailButton extends StatelessWidget {
  const VideoRailButton({super.key, this.icon, this.child, this.label, required this.onTap, this.active = false, this.activeColor});

  final IconData? icon;

  /// À la place de l'icône (par exemple le cœur animé des pièces).
  final Widget? child;
  final String? label;
  final VoidCallback onTap;
  final bool active;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final tint = active ? (activeColor ?? c.accentText) : Colors.white;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        VideoPill(child: child ?? Icon(icon, size: 22, color: tint)),
        if (label != null) ...[
          const SizedBox(height: 3),
          Text(label!, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, shadows: _kShadow)),
        ],
      ]),
    );
  }
}

/// Pastille ronde commune (40 px) : fond sombre, bord clair fin, légère ombre.
class VideoPill extends StatelessWidget {
  const VideoPill({super.key, this.child, this.size = 40});
  final Widget? child;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withOpacity(0.42),
          border: Border.all(color: Colors.white.withOpacity(0.22), width: 1),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: child,
      );
}

/// Haut de l'écran : retour (si la page a été ouverte depuis une autre), Suivis · Pour toi · Lives, et un bouton à droite (son).
class VideoTopBar extends StatelessWidget {
  const VideoTopBar({super.key, required this.index, required this.onChanged, this.onBack, this.trailing});

  final int index;
  final ValueChanged<int> onChanged;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final labels = [context.tr('Suivis'), context.tr('Pour toi'), context.tr('Lives')];
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 6, left: 10, right: 10, bottom: 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x66000000), Color(0x00000000)]),
      ),
      child: SizedBox(
        height: 40,
        child: Stack(alignment: Alignment.center, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < labels.length; i++)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 160),
                    style: TextStyle(
                      color: Colors.white.withOpacity(i == index ? 1 : 0.7),
                      fontSize: 15,
                      fontWeight: i == index ? FontWeight.w800 : FontWeight.w600,
                      shadows: _kShadow,
                      decoration: i == index ? TextDecoration.underline : TextDecoration.none,
                      decorationColor: Colors.white,
                      decorationThickness: 2.5,
                    ),
                    child: Text(labels[i]),
                  ),
                ),
              ),
          ]),
          if (onBack != null) Align(alignment: Alignment.centerLeft, child: GestureDetector(onTap: onBack, child: const VideoPill(size: 34, child: Icon(Icons.arrow_back_ios_new_rounded, size: 17, color: Colors.white)))),
          if (trailing != null) Align(alignment: Alignment.centerRight, child: trailing),
        ]),
      ),
    );
  }
}

/// « Ajouter un commentaire… » : ce n'est plus un vrai champ, il ouvre la page des commentaires (aucun commentaire écrit sur la vidéo).
class VideoCommentField extends StatelessWidget {
  const VideoCommentField({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        key: const ValueKey('video_comment_field'),
        onTap: onTap,
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.45),
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: Colors.white.withOpacity(0.22)),
          ),
          child: Text(context.tr('Ajouter un commentaire…'), style: TextStyle(color: Colors.white.withOpacity(0.88), fontSize: 13)),
        ),
      );
}

/// Fine barre de progression de la vidéo en cours, tout en bas.
class VideoProgressLine extends StatelessWidget {
  const VideoProgressLine({super.key, required this.controller});
  final VideoPlayerController? controller;

  @override
  Widget build(BuildContext context) {
    final vc = controller;
    if (vc == null) return const SizedBox(height: 2.5);
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: vc,
      builder: (_, v, __) {
        final total = v.duration.inMilliseconds;
        final f = total <= 0 ? 0.0 : (v.position.inMilliseconds / total).clamp(0.0, 1.0);
        return SizedBox(
          height: 2.5,
          child: Stack(children: [
            Container(color: Colors.white.withOpacity(0.28)),
            FractionallySizedBox(widthFactor: f, child: Container(color: Colors.white)),
          ]),
        );
      },
    );
  }
}

/// Voile doux en haut et en bas : la lecture des textes et des boutons reste bonne sur un fond clair.
class VideoShade extends StatelessWidget {
  const VideoShade({super.key});

  @override
  Widget build(BuildContext context) => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x40000000), Color(0x00000000), Color(0x00000000), Color(0x99000000)],
            stops: [0.0, 0.2, 0.55, 1.0],
          ),
        ),
        child: SizedBox.expand(),
      );
}

/// Invitation fluide à offrir un cadeau au créateur, montrée une fois qu'on regarde la vidéo depuis un moment.
/// La personne n'est jamais bloquée : « Plus tard », un toucher à côté ou un glissement vers le bas la ferme, et la vidéo continue derrière.
class VideoGiftNudge {
  static Future<void> show(
    BuildContext context, {
    required String creatorName,
    required String avatarUrl,
    required VoidCallback onGift,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'cadeau',
      barrierColor: Colors.black.withOpacity(0.28),
      transitionDuration: const Duration(milliseconds: 420),
      pageBuilder: (ctx, _, __) => _NudgeCard(creatorName: creatorName, avatarUrl: avatarUrl, onGift: () {
        Navigator.of(ctx).pop();
        onGift();
      }),
      transitionBuilder: (ctx, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero).animate(curved),
            child: ScaleTransition(scale: Tween<double>(begin: 0.94, end: 1).animate(curved), child: child),
          ),
        );
      },
    );
  }
}

class _NudgeCard extends StatelessWidget {
  const _NudgeCard({required this.creatorName, required this.avatarUrl, required this.onGift});
  final String creatorName;
  final String avatarUrl;
  final VoidCallback onGift;

  static const _gifts = [
    ('🌹', 'Rose', 10),
    ('❤️', 'Coeur', 25),
    ('👑', 'Couronne', 50),
  ];

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: Dismissible(
            key: const ValueKey('gift_nudge'),
            direction: DismissDirection.down,
            onDismissed: (_) => Navigator.of(context).maybePop(),
            child: Material(
              color: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                    decoration: BoxDecoration(
                      color: c.surface.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: const Color(0xFFFFD21F).withOpacity(0.7), width: 1.5),
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 38, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(3))),
                      const SizedBox(height: 14),
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.all(2.5),
                          decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFFD21F)),
                          child: SafeNetworkAvatar(url: avatarUrl, radius: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(context.tr('Cette vidéo te plaît ?'), style: TextStyle(color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            Text(context.tr('Remercie {a} avec un cadeau : il le reçoit tout de suite.', {'a': creatorName}), style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.3)),
                          ]),
                        ),
                      ]),
                      const SizedBox(height: 14),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                        for (final g in _gifts)
                          GestureDetector(
                            onTap: onGift,
                            child: Container(
                              width: 92,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(color: c.surfaceVariant, borderRadius: BorderRadius.circular(16)),
                              child: Column(children: [
                                Text(g.$1, style: const TextStyle(fontSize: 26)),
                                const SizedBox(height: 4),
                                Text(context.tr(g.$2), style: TextStyle(color: c.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
                                Text('${g.$3}', style: TextStyle(color: c.accentText, fontSize: 12, fontWeight: FontWeight.w800)),
                              ]),
                            ),
                          ),
                      ]),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: FilledButton(
                          onPressed: onGift,
                          style: FilledButton.styleFrom(backgroundColor: c.accent, foregroundColor: c.onAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23))),
                          child: Text(context.tr('Offrir un cadeau'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        ),
                      ),
                      TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.tr('Plus tard'), style: TextStyle(color: c.textSecondary))),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
