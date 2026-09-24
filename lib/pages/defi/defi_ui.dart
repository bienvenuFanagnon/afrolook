import 'dart:math' as math;
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/coins/coin_recharge_screen.dart';
import 'package:afrotok/pages/userPosts/userPostForm.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/theme/app_colors.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

const Color _yellow = Color(0xFFFF9500);

// ── Messages DÉFI : l'utilisateur ne voit jamais le texte d'erreur Firebase ──
class DefiDialogs {
  static Future<void> _show(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) {
        final c = AppColors.of(ctx);
        return AlertDialog(
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: _yellow, width: 1.5),
          ),
          title: Row(
            children: [
              Icon(icon, color: _yellow),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: const TextStyle(color: _yellow, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
          content: Text(message, style: TextStyle(color: c.textPrimary, fontSize: 14)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(actionLabel == null ? 'OK' : 'Fermer', style: TextStyle(color: c.textSecondary)),
            ),
            if (actionLabel != null)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _yellow,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  onAction?.call();
                },
                child: Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
          ],
        );
      },
    );
  }

  static Future<void> alreadyVoted(BuildContext context) => _show(
        context,
        icon: Icons.how_to_vote,
        title: 'Déjà voté',
        message: 'Tu as déjà voté pour cette participation. Un seul vote par personne est autorisé.',
      );

  static Future<void> alreadyParticipated(BuildContext context) => _show(
        context,
        icon: Icons.emoji_events,
        title: 'Déjà inscrit',
        message: 'Tu participes déjà à ce DÉFI. Une seule participation par personne est autorisée.',
      );

  static Future<void> defiEnded(BuildContext context) => _show(
        context,
        icon: Icons.timer_off_outlined,
        title: 'DÉFI terminé',
        message: 'Ce DÉFI est terminé : les participations et les votes sont clos.',
      );

  static Future<void> insufficientBalance(BuildContext context, {required bool isVote, bool isCreation = false}) => _show(
        context,
        icon: Icons.monetization_on,
        title: 'Solde insuffisant',
        message: isCreation
            ? "Tu n'as pas assez de pièces pour financer la cagnotte de ce DÉFI. Recharge ton solde ou baisse la cagnotte."
            : isVote
                ? "Tu n'as pas assez de pièces pour voter. Recharge ton solde pour continuer."
                : "Tu n'as pas assez de pièces pour participer à ce DÉFI. Recharge ton solde pour continuer.",
        actionLabel: 'Recharger',
        onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CoinRechargeScreen())),
      );

  static Future<void> genericError(BuildContext context, {required bool isVote, bool isCreation = false}) => _show(
        context,
        icon: Icons.error_outline,
        title: isCreation ? 'Création impossible' : isVote ? 'Vote impossible' : 'Participation impossible',
        message: isCreation
            ? "Ton DÉFI n'a pas pu être créé. Vérifie ta connexion et la configuration du DÉFI, puis réessaie. Tu n'as pas été débité."
            : isVote
                ? "Ton vote n'a pas pu être enregistré. Vérifie ta connexion et réessaie."
                : "Ta participation n'a pas pu être enregistrée. Vérifie ta connexion et réessaie. Tu n'as pas été débité.",
      );

  /// Traduit une erreur de handleDefiAction en message compréhensible.
  static Future<void> handleError(BuildContext context, Object error, {required bool isVote, bool isCreation = false}) {
    final code = error is FirebaseFunctionsException ? error.code : '';
    switch (code) {
      case 'already-exists':
        if (isCreation) return genericError(context, isVote: false, isCreation: true);
        return isVote ? alreadyVoted(context) : alreadyParticipated(context);
      case 'resource-exhausted':
        return insufficientBalance(context, isVote: isVote, isCreation: isCreation);
      case 'failed-precondition':
        return defiEnded(context);
      default:
        return genericError(context, isVote: isVote, isCreation: isCreation);
    }
  }
}

bool isDefiOver(Post defiPost) {
  final cfg = defiPost.defiConfig;
  if (cfg == null) return false;
  return cfg.isTermine ||
      (cfg.endDate > 0 && DateTime.fromMillisecondsSinceEpoch(cfg.endDate).isBefore(DateTime.now()));
}

/// Badge affiché à la place de "Participer" quand le DÉFI est terminé.
class DefiEndedChip extends StatelessWidget {
  const DefiEndedChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withOpacity(0.45)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flag_outlined, size: 14, color: Colors.grey),
          SizedBox(width: 4),
          Text('Terminé', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Bouton "Participer" : contrôles locaux (déjà inscrit, DÉFI terminé, solde) avant d'ouvrir le formulaire.
void openDefiParticipation(BuildContext context, Post defiPost) {
  final auth = Provider.of<UserAuthProvider>(context, listen: false);
  final cfg = defiPost.defiConfig;
  if (defiPost.defiParticipantIds?.contains(auth.loginUserData.id) ?? false) {
    DefiDialogs.alreadyParticipated(context);
    return;
  }
  if (isDefiOver(defiPost)) {
    DefiDialogs.defiEnded(context);
    return;
  }
  final fee = cfg?.participationFee ?? 0;
  if (fee > 0 && (auth.loginUserData.giftCoinsBalance ?? 0) < fee) {
    DefiDialogs.insufficientBalance(context, isVote: false);
    return;
  }
  Navigator.push(context, MaterialPageRoute(builder: (_) => UserPostForm(defiPostId: defiPost.id!)));
}

/// Animation "+1 Vote" partant du widget [anchor] (ou du centre de l'écran).
void showDefiVoteAnimation(BuildContext context, {GlobalKey? anchor}) {
  final box = anchor?.currentContext?.findRenderObject() as RenderBox?;
  final size = MediaQuery.of(context).size;
  final pos = box != null && box.attached
      ? box.localToGlobal(Offset(box.size.width / 2, box.size.height / 2))
      : Offset(size.width / 2, size.height * 0.6);
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  entry = OverlayEntry(builder: (_) => _VoteSuccessOverlay(start: pos, onDone: () => entry.remove()));
  overlay.insert(entry);
}

class _VoteSuccessOverlay extends StatefulWidget {
  final Offset start;
  final VoidCallback onDone;
  const _VoteSuccessOverlay({required this.start, required this.onDone});

  @override
  State<_VoteSuccessOverlay> createState() => _VoteSuccessOverlayState();
}

class _VoteSuccessOverlayState extends State<_VoteSuccessOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _p;
  final _rnd = math.Random();
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _particles = List.generate(7, (_) => _Particle(
      dx: (_rnd.nextDouble() - 0.5) * 160,
      dy: -(90 + _rnd.nextDouble() * 140),
      rotation: (_rnd.nextDouble() - 0.5) * 0.9,
      size: 18 + _rnd.nextDouble() * 14,
      emoji: const ['🏆', '⭐', '🗳️', '✨'][_rnd.nextInt(4)],
    ));
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _p = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double _opacity(double p) => p < 0.7 ? 1.0 : (1.0 - (p - 0.7) / 0.3).clamp(0.0, 1.0);

  double _scale(double p) {
    if (p < 0.25) return 0.5 + (p / 0.25) * 0.8;
    if (p < 0.7) return 1.3;
    return (1.3 - ((p - 0.7) / 0.3) * 0.6).clamp(0.3, 1.5);
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _p,
        builder: (_, __) {
          final p = _p.value;
          final op = _opacity(p);
          return Stack(
            children: [
              ..._particles.map((pt) => Positioned(
                    left: widget.start.dx + pt.dx * p - pt.size / 2,
                    top: widget.start.dy + pt.dy * p - pt.size / 2,
                    child: Opacity(
                      opacity: op,
                      child: Transform.rotate(
                        angle: pt.rotation * (p < 0.5 ? p * 2 : (1 - p) * 2),
                        child: Transform.scale(
                          scale: _scale(p),
                          child: Text(pt.emoji, style: TextStyle(fontSize: pt.size, decoration: TextDecoration.none)),
                        ),
                      ),
                    ),
                  )),
              Positioned(
                left: widget.start.dx - 60,
                top: widget.start.dy - 30 - 110 * p,
                width: 120,
                child: Opacity(
                  opacity: op,
                  child: Transform.scale(
                    scale: _scale(p),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _yellow,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: _yellow.withOpacity(0.5), blurRadius: 14)],
                        ),
                        child: const Text(
                          '+1 Vote',
                          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, decoration: TextDecoration.none),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Particle {
  final double dx, dy, rotation, size;
  final String emoji;
  const _Particle({required this.dx, required this.dy, required this.rotation, required this.size, required this.emoji});
}
