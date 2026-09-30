import 'package:flutter/material.dart';

import '../../l10n/tr.dart';
import '../../services/stickers/sticker_models.dart';
import '../../theme/app_colors.dart';
import '../user/userAbonnementPage.dart';

const Color kStickerGold = Color(0xFFD99A00);

/// Texte clair pour une raison renvoyée par `stickerAccess`.
String stickerReasonText(BuildContext context, String? reason) {
  switch (reason) {
    case 'not_subscribed':
      return context.tr('Les stickers sont réservés aux abonnés Premium');
    case 'suspended':
      return context.tr('Les stickers sont suspendus pour ton compte');
    case 'day_limit':
      return context.tr('Limite de stickers du jour atteinte');
    case 'post_limit':
      return context.tr('Limite de stickers atteinte sur ce post');
    case 'not_owned':
      return context.tr('Pack non acheté');
    case 'inactive':
      return context.tr('Sticker indisponible');
    case 'removed':
      return context.tr('Sticker retiré');
    case 'no_coins':
      return context.tr('Pièces insuffisantes');
    default:
      return context.tr('Sticker indisponible');
  }
}

/// Petit badge doré « PREMIUM ».
class StickerPremiumBadge extends StatelessWidget {
  const StickerPremiumBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD700),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'PREMIUM',
        style: TextStyle(fontSize: 6.5, fontWeight: FontWeight.w900, color: Color(0xFF121212), height: 1.1),
      ),
    );
  }
}

/// Feuille d'invitation à s'abonner (compte gratuit).
Future<void> showStickerPremiumInvite(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final c = AppColors.of(ctx);
      return SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: const Color(0xFFFFD700).withOpacity(0.2), shape: BoxShape.circle),
                child: const Icon(Icons.sticky_note_2_outlined, color: kStickerGold, size: 30),
              ),
              const SizedBox(height: 12),
              Text(
                ctx.tr('Les stickers, c\'est Premium'),
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                ctx.tr('Réponds aux commentaires avec des stickers animés. Abonne-toi à Premium pour les débloquer.'),
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textSecondary, fontSize: 13.5, height: 1.35),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.primary,
                    foregroundColor: c.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AbonnementScreen()));
                  },
                  child: Text(ctx.tr('Voir les abonnements'), style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(ctx.tr('Plus tard'), style: TextStyle(color: c.textSecondary)),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Image d'un sticker : miniature en repli, animation par-dessus.
class StickerImage extends StatelessWidget {
  final StickerItem sticker;
  final double? size;
  final bool loadAnimation;

  const StickerImage({super.key, required this.sticker, this.size, this.loadAnimation = true});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    Widget thumb() => Image.network(
          sticker.thumbUrl,
          width: size,
          height: size,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => Icon(Icons.image_not_supported_outlined, color: c.textSecondary, size: 20),
        );
    if (!loadAnimation || sticker.url.isEmpty || sticker.url == sticker.thumbUrl) return thumb();
    return Image.network(
      sticker.url,
      width: size,
      height: size,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      frameBuilder: (ctx, child, frame, sync) => (frame == null && !sync) ? thumb() : child,
      errorBuilder: (_, __, ___) => thumb(),
    );
  }
}
