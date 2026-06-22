// pages/live/live_widgets.dart
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
              'Accès au live payant',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Ce live est payant. Payez ${live.participationFee.toInt()} FCFA pour continuer à regarder.',
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              '70% pour le créateur • 30% pour la plateforme',
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
                    child: Text('Quitter', style: TextStyle(color: Colors.white70)),
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
                      'Payer ${live.participationFee.toInt()} FCFA',
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
              'Rejoindre le live',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Comment souhaitez-vous rejoindre ce live?',
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
                      '🎤 Participant (100 FCFA)',
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

class GiftPanelWidget extends StatelessWidget {
  final List<Gift> gifts;
  final Function(Gift) onGiftSelected;
  final VoidCallback onClose;

  const GiftPanelWidget({
    Key? key,
    required this.gifts,
    required this.onGiftSelected,
    required this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.6;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: onClose,
            child: Container(color: Colors.black54),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Envoyer un cadeau',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.white),
                        onPressed: onClose,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 0.8,
                    ),
                    itemCount: gifts.length,
                    itemBuilder: (context, index) {
                      final gift = gifts[index];
                      return GestureDetector(
                        onTap: () => onGiftSelected(gift),
                        child: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: gift.color, width: 2),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(gift.icon, style: TextStyle(fontSize: 24)),
                              SizedBox(height: 4),
                              Text(gift.name,
                                  style: TextStyle(color: Colors.white, fontSize: 10),
                                  textAlign: TextAlign.center),
                              SizedBox(height: 2),
                              Text('${gift.price.toInt()} pcs',
                                  style: TextStyle(color: Color(0xFFF9A825), fontSize: 10)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
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
                        CircleAvatar(
                          backgroundImage: NetworkImage(user.imageUrl ?? ''),
                          radius: 16,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.pseudo ?? 'Utilisateur',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                isHost ? 'Hôte' : (isParticipant ? 'Participant' : 'Spectateur'),
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
              'Texte épinglé',
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
                hintText: 'Entrez votre message...',
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
                    child: Text('Épingler', style: TextStyle(color: Colors.black)),
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