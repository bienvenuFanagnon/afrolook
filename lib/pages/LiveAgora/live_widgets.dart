// pages/live/live_widgets.dart
import 'package:afrotok/l10n/tr.dart';
import 'package:afrotok/widgets/name_tag.dart';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:afrotok/utils/platform_guard.dart';
import 'package:afrotok/services/coin_checkout.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import '../../models/model_data.dart';
import 'livesAgora.dart';

// ==================== WIDGETS MODAUX ====================

class PaymentRequiredDialog extends StatelessWidget {
  final PostLive live;
  final VoidCallback onPayment;
  final VoidCallback onLeave;

  const PaymentRequiredDialog({
    Key? key,
    required this.live,
    required this.onPayment,
    required this.onLeave,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock, size: 64, color: Color(0xFFF9A825)),
            SizedBox(height: 16),
            Text(
              context.tr('Accès au live payant'),
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Text(
              context.tr('Ce live est privé. Payez {p} pour continuer à regarder.', {'p': CoinCheckout.coinsLabel(live.participationFeeCoins)}),
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              context.tr('70% pour le créateur'),
              style: TextStyle(color: Colors.green, fontSize: 12),
            ),
            SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: onLeave,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(context.tr('Quitter'), style: TextStyle(color: Colors.white70)),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFF9A825),
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      context.tr('Payer l\'entrée : {n} pièces', {'n': CoinCheckout.fmt(live.participationFeeCoins)}),
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class JoinLiveDialog extends StatelessWidget {
  final String liveId;
  final VoidCallback onJoinAsParticipant;
  final VoidCallback onJoinAsSpectator;

  const JoinLiveDialog({
    Key? key,
    required this.liveId,
    required this.onJoinAsParticipant,
    required this.onJoinAsSpectator,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.video_camera_front, size: 48, color: Color(0xFFF9A825)),
            SizedBox(height: 16),
            Text(
              tr('Rejoindre le live'),
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Text(
              tr('Comment souhaitez-vous rejoindre ce live?'),
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: onJoinAsSpectator,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Colors.grey[800],
                    ),
                    child: Text(
                      '👀 Spectateur (Gratuit)',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
                SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onJoinAsParticipant,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFF9A825),
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      tr('🎤 Participant (250 pièces)'),
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Panneau d'envoi de cadeau : feuille douce (dégradé sombre, coins très arrondis), les cadeaux ENVOYÉS RÉCEMMENT sur une ligne en haut, puis tous les autres.
/// Un toucher envoie ; la carte touchée montre un petit sablier pendant l'envoi (jamais un toucher qui ne fait « rien »).
class GiftPanelWidget extends StatefulWidget {
  final List<Gift> gifts;
  final List<String> recentIds;   // identifiants des cadeaux envoyés récemment, le plus récent d'abord
  final Future<void> Function(Gift) onGiftSelected;
  final VoidCallback onClose;
  final bool isHost;

  const GiftPanelWidget({
    Key? key,
    required this.gifts,
    required this.onGiftSelected,
    required this.onClose,
    this.recentIds = const [],
    this.isHost = false,
  }) : super(key: key);

  @override
  State<GiftPanelWidget> createState() => _GiftPanelWidgetState();
}

class _GiftPanelWidgetState extends State<GiftPanelWidget> {
  String? _busyId;

  Future<void> _tap(Gift g) async {
    if (_busyId != null) return;
    setState(() => _busyId = g.id);
    try {
      await widget.onGiftSelected(g);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Widget _card(Gift g, {bool compact = false}) {
    final busy = _busyId == g.id;
    final c = g.color;
    return GestureDetector(
      onTap: () => _tap(g),
      child: AnimatedScale(
        scale: busy ? 0.94 : 1,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: compact ? 76 : null,
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: compact ? 8 : 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [c.withOpacity(.16), Colors.white.withOpacity(.05)]),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.withOpacity(.35)),
          ),
          child: Stack(alignment: Alignment.center, children: [
            Opacity(
              opacity: busy ? .35 : 1,
              child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(g.icon, style: TextStyle(fontSize: compact ? 26 : 30)),
                const SizedBox(height: 4),
                Text(g.name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFF9A825).withOpacity(.16), borderRadius: BorderRadius.circular(99)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.stars_rounded, color: Color(0xFFF9A825), size: 10),
                    const SizedBox(width: 3),
                    Text('${g.price.toInt()}', style: const TextStyle(color: Color(0xFFFFD27A), fontSize: 10.5, fontWeight: FontWeight.w800)),
                  ]),
                ),
              ]),
            ),
            if (busy) const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70)),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.62;
    final byId = {for (final g in widget.gifts) g.id: g};
    final recent = [for (final id in widget.recentIds) if (byId.containsKey(id)) byId[id]!].take(8).toList();
    final recentSet = recent.map((g) => g.id).toSet();
    final rest = [for (final g in widget.gifts) if (!recentSet.contains(g.id)) g];
    return Stack(
      children: [
        Positioned.fill(child: GestureDetector(onTap: widget.onClose, child: Container(color: Colors.black.withOpacity(.55)))),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: height,
            decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF26223A), Color(0xFF15121F)]),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
              boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 24)],
            ),
            child: Column(children: [
              const SizedBox(height: 8),
              Container(width: 38, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(99))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
                child: Row(children: [
                  Expanded(child: Text(tr('Envoyer un cadeau'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18))),
                  IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white54), onPressed: widget.onClose),
                ]),
              ),
              if (widget.isHost)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(.07), borderRadius: BorderRadius.circular(14)),
                  child: Row(children: [
                    const Icon(Icons.info_outline_rounded, color: Colors.white54, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(tr('Tu es l\'hôte : tu ne peux pas t\'offrir un cadeau. Toucher un cadeau montre seulement son animation.'), style: const TextStyle(color: Colors.white60, fontSize: 11.5, height: 1.3))),
                  ]),
                ),
              Expanded(
                child: CustomScrollView(slivers: [
                  if (recent.isNotEmpty) ...[
                    SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 6), child: Text(tr('Envoyés récemment'), style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w700)))),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 112,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          itemCount: recent.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (_, i) => _card(recent[i], compact: true),
                        ),
                      ),
                    ),
                  ],
                  SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 6), child: Text(recent.isEmpty ? tr('Tous les cadeaux') : tr('Les autres cadeaux'), style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w700)))),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: .78),
                      delegate: SliverChildBuilderDelegate((_, i) => _card(rest[i]), childCount: rest.length),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class UsersPanelWidget extends StatelessWidget {
  final List<UserData> users;
  final String hostId;
  final List<String> participants;
  final VoidCallback onClose;

  const UsersPanelWidget({
    Key? key,
    required this.users,
    required this.hostId,
    required this.participants,
    required this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 100,
      right: 16,
      bottom: 100,
      width: MediaQuery.of(context).size.width * 0.7,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Color(0xFFF9A825), width: 1),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Participants (${users.length})',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: onClose,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  final isHost = user.id == hostId;
                  final isParticipant = participants.contains(user.id);

                  return Container(
                    margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(onBackgroundImageError: (_, __) {}, 
                          backgroundImage: NetworkImage(user.imageUrl ?? ''),
                          radius: 16,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              NameTag(label: '@${user.pseudo ?? 'Utilisateur'}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                )),
                              Text(
                                isHost ? tr('Hôte') : (isParticipant ? 'Participant' : 'Spectateur'),
                                style: TextStyle(
                                  color: isHost ? Color(0xFFF9A825) : Colors.white70,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isHost)
                          Icon(Icons.star, color: Color(0xFFF9A825), size: 16),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PinnedTextEditorWidget extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  const PinnedTextEditorWidget({
    Key? key,
    required this.controller,
    required this.onSave,
    required this.onCancel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 100,
      left: 50,
      right: 50,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Color(0xFFF9A825), width: 2),
        ),
        child: Column(
          children: [
            Text(
              tr('Texte épinglé'),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: controller,
              style: TextStyle(color: Colors.white),
              maxLines: 2,
              decoration: InputDecoration(
                hintText: tr('Entrez votre message...'),
                hintStyle: TextStyle(color: Colors.white54),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFF9A825)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFF9A825)),
                ),
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: onCancel,
                    child: Text('Annuler', style: TextStyle(color: Colors.white70)),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFF9A825),
                    ),
                    child: Text(tr('Épingler'), style: TextStyle(color: Colors.black)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== ANIMATIONS ====================

class LikeAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const LikeAnimation({
    Key? key,
    required this.child,
    this.duration = const Duration(milliseconds: 2000),
  }) : super(key: key);

  @override
  _LikeAnimationState createState() => _LikeAnimationState();
}

class _LikeAnimationState extends State<LikeAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.5,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Interval(0.5, 1.0),
    ));

    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          setState(() {});
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: widget.child,
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

// EFFET TIKTOK LIKE — style TikTok fluide, cœurs montant depuis le bas droit
class TikTokLikeEffect extends StatefulWidget {
  final LikeEffect effect;
  const TikTokLikeEffect({Key? key, required this.effect}) : super(key: key);
  @override
  State<TikTokLikeEffect> createState() => _TikTokLikeEffectState();
}

class _TikTokLikeEffectState extends State<TikTokLikeEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;
  final _rng = Random();
  late final double _dx;
  late final Color _color;

  static const _palette = [
    Colors.red,
    Colors.pinkAccent,
    Color(0xFFFF6B6B),
    Colors.redAccent,
    Color(0xFFE91E63),
  ];

  @override
  void initState() {
    super.initState();
    // Léger décalage horizontal aléatoire pour que les cœurs ne se superposent pas
    _dx = (_rng.nextDouble() - 0.5) * 36;
    _color = _palette[_rng.nextInt(_palette.length)];

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..forward();

    // Pop élastique à l'apparition → légère réduction → disparition
    _scale = TweenSequence([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.35)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 28,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.35, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 12,
      ),
      TweenSequenceItem(
        tween: ConstantTween(1.0),
        weight: 60,
      ),
    ]).animate(_ctrl);

    // Reste pleinement visible jusqu'à 65 %, puis fondu rapide
    _opacity = TweenSequence([
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 65),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 35,
      ),
    ]).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // Toujours en bas à droite, comme TikTok
    final baseX = size.width * 0.81 + _dx;
    final baseY = size.height * 0.76;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final rise = _ctrl.value * 220;
        // Légère courbe sinusoïdale horizontale
        final wobble = sin(_ctrl.value * pi * 2.5) * 10;
        return Positioned(
          left: baseX + wobble,
          top: baseY - rise,
          child: Opacity(
            opacity: _opacity.value.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: _scale.value,
              child: Icon(
                Icons.favorite_rounded,
                color: _color,
                size: 32,
                shadows: const [
                  Shadow(blurRadius: 4, color: Colors.black26),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class HeartParticle {
  final double xOffset;
  final double yOffset;
  final double scale;
  final double rotation;
  final double delay;

  HeartParticle({
    required this.xOffset,
    required this.yOffset,
    required this.scale,
    required this.rotation,
    required this.delay,
  });
}

// EFFET CADEAU
class GiftAnimation extends StatefulWidget {
  final Gift gift;

  const GiftAnimation({Key? key, required this.gift}) : super(key: key);

  @override
  _GiftAnimationState createState() => _GiftAnimationState();
}

class _GiftAnimationState extends State<GiftAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 3000),
      vsync: this,
    )..forward();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -_controller.value * 100),
          child: Opacity(
            opacity: 1 - _controller.value,
            child: Text(
              widget.gift.icon,
              style: TextStyle(fontSize: 40),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

// ==================== CLASSES SUPPORT ====================

class Gift {
  final String id;
  final String name;
  final double price;
  final String icon;
  final Color color;

  Gift({
    required this.id,
    required this.name,
    required this.price,
    required this.icon,
    required this.color,
  });
}

class LikeEffect {
  final String id;
  final String userId;
  final String username;
  final String userImage;
  final DateTime timestamp;

  // Plus besoin de x, y, isDoubleTap car la position est fixe
  LikeEffect({
    required this.id,
    required this.userId,
    required this.username,
    required this.userImage,
    required this.timestamp,
  });
}

class GiftEffect {
  final int id;
  final Gift gift;
  final double x;

  GiftEffect({required this.id, required this.gift, required this.x});
}