import 'package:flutter/material.dart';
import '../models/model_data.dart';
import '../pages/coins/coin_recharge_screen.dart';
import '../providers/authProvider.dart';
import '../providers/coin_gift_provider.dart';
import '../theme/app_colors.dart';

/// Animation centrée style "double-tap like" — cœur spring-bounce + message de soutien.
/// Appelé depuis toute page qui gère le like avec pièces.
void showLikeOverlay(BuildContext context, {String creatorName = ''}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _LikeOverlay(
      creatorName: creatorName,
      onDone: () {
        try { entry.remove(); } catch (_) {}
      },
    ),
  );
  overlay.insert(entry);
}

class _LikeOverlay extends StatefulWidget {
  final String creatorName;
  final VoidCallback onDone;
  const _LikeOverlay({required this.creatorName, required this.onDone});
  @override
  State<_LikeOverlay> createState() => _LikeOverlayState();
}

class _LikeOverlayState extends State<_LikeOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _opacity;
  late Animation<double> _translateY;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.2, end: 1.15)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.15, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 10,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 40),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.8)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 25,
      ),
    ]).animate(_ctrl);

    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 12),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 63),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 25),
    ]).animate(_ctrl);

    _translateY = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 75),
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: -50.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 25,
      ),
    ]).animate(_ctrl);

    _ctrl.forward().then((_) => widget.onDone());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Positioned.fill(
        child: IgnorePointer(
          child: Material(
            color: Colors.transparent,
            child: Opacity(
              opacity: _opacity.value,
            child: Transform.translate(
              offset: Offset(0, _translateY.value),
              child: Center(
                child: Transform.scale(
                  scale: _scale.value,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Cœur ──
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(
                            colors: [Color(0xFFFF8FAB), Color(0xFFE8003D)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE8003D).withOpacity(0.45),
                              blurRadius: 22,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text('❤️', style: TextStyle(fontSize: 40)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      // ── Message ──
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.72),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: const Color(0xFFE8003D).withOpacity(0.35),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🪙', style: TextStyle(fontSize: 14)),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8003D).withOpacity(0.25),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                '+1',
                                style: TextStyle(
                                  color: Color(0xFFFF8FAB),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.creatorName.isNotEmpty
                                  ? 'Votre like rapporte 1 🪙 à @${widget.creatorName} !'
                                  : 'Votre like rapporte 1 🪙 au créateur du post !',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          ), // Material
        ),
      ),
    );
  }
}

/// Dialog "solde insuffisant" unifié pour tous les widgets de like.
void showInsufficientCoinsForLikeDialog({
  required BuildContext context,
  required UserData user,
  required CoinGiftUserProvider coinProvider,
  required UserAuthProvider authProvider,
}) {
  final hasClaimed = user.hasClaimedFreeCoins ?? false;
  showDialog(
    context: context,
    builder: (ctx) {
      final dc = AppColors.of(ctx);
      return AlertDialog(
        backgroundColor: dc.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '💙 Soutenez vos créateurs !',
          style: TextStyle(color: dc.primary, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Text('🪙', style: TextStyle(fontSize: 15)),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Solde insuffisant',
                    style: TextStyle(color: dc.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
                Text(
                  'Votre solde : ${user.giftCoinsBalance ?? 0} pièce${(user.giftCoinsBalance ?? 0) > 1 ? 's' : ''} · Il faut 2 pièces',
                  style: TextStyle(color: dc.textSecondary, fontSize: 11),
                ),
              ]),
            ]),
            const SizedBox(height: 12),
            Divider(color: dc.border, height: 1),
            const SizedBox(height: 12),
            Text(
              'Votre like offre des pièces au créateur — c\'est ainsi qu\'il monétise son contenu sur Afrolook et aussi par des vues rémunérées à 1 000 F le RPM. Les meilleurs créateurs gagnent jusqu\'à 15 000 pièces par post.',
              style: TextStyle(color: dc.textSecondary, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 8),
            Text('💎 Vous pouvez obtenir 500 pièces à 250 FCFA',
                style: TextStyle(color: dc.textSecondary, fontSize: 12)),
            if (!hasClaimed) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: dc.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: dc.primary.withOpacity(0.25)),
                ),
                child: Row(children: [
                  const Text('🎁', style: TextStyle(fontSize: 15)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    'Offre unique : 10 pièces gratuites à encaisser maintenant !',
                    style: TextStyle(color: dc.primary, fontSize: 12, fontWeight: FontWeight.w600),
                  )),
                ]),
              ),
            ],
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          // Boutons principaux côte à côte
          Row(children: [
            if (!hasClaimed) ...[
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Text('🎁', style: TextStyle(fontSize: 12)),
                  label: const Text('10 pièces gratuites',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final ok = await coinProvider.claimFreeCoins(user.id!);
                    if (ok) {
                      await authProvider.refreshUserData();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: const Text('🎁 10 pièces créditées ! Soutenez un créateur.'),
                          backgroundColor: AppColors.of(context).primary,
                          duration: const Duration(seconds: 3),
                        ));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: dc.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const CoinRechargeScreen()));
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: dc.primary,
                  side: BorderSide(color: dc.primary),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Recharger →',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ),
          ]),
          // Annuler discret centré en dessous
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Annuler', style: TextStyle(color: dc.textSecondary, fontSize: 12)),
            ),
          ),
        ],
      );
    },
  );
}

/// Widget message de soutien — s'affiche au-dessus des boutons d'action après un like réussi.
class LikeSupportMessage extends StatelessWidget {
  const LikeSupportMessage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 6, left: 4, right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colors.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.primary.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🪙', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 6),
          Text(
            'Merci d\'avoir soutenu ce créateur !',
            style: TextStyle(
              color: colors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
