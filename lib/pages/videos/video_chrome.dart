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


/// Pastille d'action claire de la page vidéo paysage (j'aime, commentaires, cadeau, partager, menu) : même famille d'icônes que la page verticale.
class VideoActionChip extends StatelessWidget {
  const VideoActionChip({super.key, required this.icon, this.label, required this.onTap, this.active = false, this.activeColor});

  final IconData icon;
  final String? label;
  final VoidCallback onTap;
  final bool active;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final tint = active ? (activeColor ?? c.danger) : c.textPrimary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: label == null ? 11 : 13, vertical: 9),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(99), border: Border.all(color: c.border)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 19, color: tint),
          if (label != null) ...[
            const SizedBox(width: 6),
            Text(label!, style: TextStyle(color: c.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
          ],
        ]),
      ),
    );
  }
}

/// « Ajouter un commentaire… » de la page paysage : ouvre la page des commentaires.
class VideoCommentFieldLight extends StatelessWidget {
  const VideoCommentFieldLight({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      key: const ValueKey('video_comment_field_light'),
      onTap: onTap,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(color: c.surfaceVariant, borderRadius: BorderRadius.circular(21), border: Border.all(color: c.border)),
        child: Text(context.tr('Ajouter un commentaire…'), style: TextStyle(color: c.textSecondary, fontSize: 14)),
      ),
    );
  }
}


/// Gestes sur la vidéo verticale : un toucher met en pause ou reprend, deux touchers rapides aiment (comme avant), un glissement horizontal avance ou recule.
/// Le toucher agit tout de suite (pas d'attente) ; si un deuxième toucher suit dans les 300 ms, le premier est annulé et c'est un « j'aime ».
class VideoGestureLayer extends StatefulWidget {
  const VideoGestureLayer({super.key, required this.controller, required this.onDoubleTap, required this.child});

  /// Lecteur de cette page (null si ce n'est pas la vidéo en cours : aucun geste de lecture).
  final VideoPlayerController? controller;
  final VoidCallback onDoubleTap;
  final Widget child;

  @override
  State<VideoGestureLayer> createState() => _VideoGestureLayerState();
}

class _VideoGestureLayerState extends State<VideoGestureLayer> {
  DateTime? _lastTap;
  bool _dragging = false;
  bool _wasPlaying = false;
  Duration _start = Duration.zero;
  Duration _pos = Duration.zero;
  double _dx = 0;

  void _toggle() {
    final vc = widget.controller;
    if (vc == null || !vc.value.isInitialized) return;
    vc.value.isPlaying ? vc.pause() : vc.play();
  }

  void _tap() {
    final now = DateTime.now();
    final last = _lastTap;
    if (last != null && now.difference(last) < const Duration(milliseconds: 300)) {
      _lastTap = null;
      _toggle();   // annule la pause du premier toucher
      widget.onDoubleTap();
      return;
    }
    _lastTap = now;
    _toggle();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString();
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final vc = widget.controller;
    final width = MediaQuery.of(context).size.width;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _tap,
      onHorizontalDragStart: vc == null || !vc.value.isInitialized
          ? null
          : (_) {
              _dragging = true;
              _wasPlaying = vc.value.isPlaying;
              _start = vc.value.position;
              _pos = _start;
              _dx = 0;
              vc.pause();
              setState(() {});
            },
      onHorizontalDragUpdate: vc == null || !_dragging
          ? null
          : (d) {
              _dx += d.delta.dx;
              final total = vc.value.duration.inMilliseconds;
              final target = (_start.inMilliseconds + total * (_dx / width)).round().clamp(0, total);
              setState(() => _pos = Duration(milliseconds: target));
            },
      onHorizontalDragEnd: vc == null || !_dragging
          ? null
          : (_) async {
              _dragging = false;
              await vc.seekTo(_pos);
              if (_wasPlaying) await vc.play();
              if (mounted) setState(() {});
            },
      onHorizontalDragCancel: () {
        if (_dragging) {
          _dragging = false;
          if (_wasPlaying) vc?.play();
          if (mounted) setState(() {});
        }
      },
      child: Stack(fit: StackFit.expand, children: [
        widget.child,
        if (vc != null)
          IgnorePointer(
            child: ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: vc,
              builder: (context, v, _) {
                if (_dragging) {
                  return Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), borderRadius: BorderRadius.circular(16)),
                      child: Text('${_fmt(_pos)} / ${_fmt(v.duration)}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                    ),
                  );
                }
                // en pause : un grand bouton lecture discret au centre
                if (v.isInitialized && !v.isPlaying) {
                  return Center(child: VideoPill(size: 72, child: const Icon(Icons.play_arrow_rounded, size: 44, color: Colors.white)));
                }
                return const SizedBox.shrink();
              },
            ),
          ),
      ]),
    );
  }
}

/// Badge vert « Validé » : aucune marque d'un autre réseau n'a été détectée après plusieurs contrôles.
class AuthenticBadge extends StatelessWidget {
  const AuthenticBadge({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
        key: const ValueKey('authentic_badge'),
        padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: 2),
        decoration: BoxDecoration(color: const Color(0xF21B8A3C), borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.verified_rounded, size: compact ? 11 : 12, color: Colors.white),
          const SizedBox(width: 3),
          Text(context.tr('Validé'), style: TextStyle(color: Colors.white, fontSize: compact ? 9 : 10, fontWeight: FontWeight.w800)),
        ]),
      );
}

/// Pastille jaune d'une vidéo marquée : « Ce post n'est plus monétisé · En savoir plus ».
class NotMonetizedChip extends StatelessWidget {
  const NotMonetizedChip({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        key: const ValueKey('not_monetized_chip'),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(color: const Color(0xF5FFC400), borderRadius: BorderRadius.circular(99), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 3))]),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.warning_amber_rounded, size: 15, color: Color(0xFF3A2C00)),
            const SizedBox(width: 6),
            Flexible(child: Text(context.tr('Ce post n\'est plus monétisé · En savoir plus'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF3A2C00), fontSize: 11, fontWeight: FontWeight.w800))),
            const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF3A2C00)),
          ]),
        ),
      );
}

/// Feuille d'explication d'une vidéo marquée : pourquoi elle n'est plus monétisée, ce qui change, et « C'est ma vidéo ».
Future<void> showNotMonetizedSheet(BuildContext context, {required String mark, bool isOwner = false, VoidCallback? onOwnClaim}) {
  final c = AppColors.of(context);
  final name = switch (mark) {
    'tiktok' => 'TikTok',
    'instagram' => 'Instagram',
    'facebook' => 'Facebook',
    _ => context.tr('d\'autres réseaux'),
  };
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: c.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 38, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(3)))),
          const SizedBox(height: 14),
          Text(context.tr('Pourquoi ce post n\'est plus monétisé ?'), style: TextStyle(color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(context.tr('Plusieurs lectures de cette vidéo ont montré la marque d\'un autre réseau ({a}). Afrolook met en avant les contenus authentiques, propres à la plateforme.', {'a': name}), style: TextStyle(color: c.textSecondary, fontSize: 14, height: 1.45)),
          const SizedBox(height: 10),
          for (final t in [context.tr('Les vues de ce post ne rapportent plus de pièces.'), context.tr('Il reste visible, mais n\'est plus mis en avant.'), context.tr('Les cadeaux restent possibles.')])
            Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('•  ', style: TextStyle(color: c.textSecondary)), Expanded(child: Text(t, style: TextStyle(color: c.textSecondary, fontSize: 13.5, height: 1.4)))])),
          if (isOwner) ...[
            const SizedBox(height: 10),
            Text(context.tr('C\'est ta vidéo ? Dis-le-nous : notre équipe la vérifie.'), style: TextStyle(color: c.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  onOwnClaim?.call();
                },
                style: FilledButton.styleFrom(backgroundColor: c.accent, foregroundColor: c.onAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23))),
                child: Text(context.tr('C\'est ma vidéo'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ),
          ],
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('Fermer'), style: TextStyle(color: c.textSecondary))),
        ]),
      ),
    ),
  );
}
