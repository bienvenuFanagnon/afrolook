// Feuille du bas affichée à la fin de l'extrait gratuit d'un titre payant :
// remercie, parle de l'artiste, propose d'acheter (pièces), d'écouter en entier avec une pub, ou de créer un post avec ce son.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../ads/music_ads.dart';
import '../../pages/coins/coin_recharge_screen.dart';
import '../../pages/studio/artist_marketplace.dart';
import '../../pages/studio/montage/montage_music.dart';
import '../../providers/authProvider.dart';
import '../../services/music_queue.dart';
import '../../theme/app_colors.dart';
import 'vinyl.dart';

enum PreviewEnd { buy, topup, ad, post, later }

/// Ouvre la feuille. [ctx] doit être sous le Navigator (contexte de page ou de la clé de navigation).
Future<void> showPreviewEndSheet(BuildContext ctx, MusicTrack t, {VoidCallback? onClosed}) async {
  final user = Provider.of<UserAuthProvider>(ctx, listen: false).loginUserData;
  final balance = user.giftCoinsBalance ?? 0;
  final r = await showModalBottomSheet<PreviewEnd>(
    context: ctx,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => PreviewEndSheet(track: t, balance: balance, canAd: t.sound != null && MusicAds.canOfferRewarded(user)),
  );
  onClosed?.call(); // la feuille est fermée : le bouton « Débloquer » redevient actif même si l'achat ou la pub qui suit dure
  if (r == null || r == PreviewEnd.later || !ctx.mounted) return;
  final s = t.sound;
  switch (r) {
    case PreviewEnd.buy:
      if (s == null) return;
      final ok = await buyTrack(ctx, s);
      if (ok) await MusicQueue.playTrack(MusicTrack.fromSound(s, owned: true), interstitial: false);
    case PreviewEnd.topup:
      await Navigator.push(ctx, MaterialPageRoute(builder: (_) => const CoinRechargeScreen()));
    case PreviewEnd.ad:
      final res = await MusicAds.listenWithAd(t.id, userId: FirebaseAuth.instance.currentUser?.uid ?? '');
      if (!ctx.mounted) return;
      if (res.outcome != MusicAdOutcome.ok || res.url == null) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(MusicAds.message(res.outcome))));
        return;
      }
      await MusicQueue.playGranted(t, res.url!);
    case PreviewEnd.post:
      if (s != null) await startPostWithMusic(ctx, MontageMusic.artist(s));
    case PreviewEnd.later:
      break;
  }
}

/// Contenu de la feuille (public pour les tests).
class PreviewEndSheet extends StatelessWidget {
  const PreviewEndSheet({required this.track, required this.balance, required this.canAd});
  final MusicTrack track;
  final int balance;
  final bool canAd;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = track;
    final forSale = t.saleCoins > 0 && !t.isMine;
    final enough = balance >= t.saleCoins;
    final use = t.useCoins;
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: BoxDecoration(color: c.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(22))),
      padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 14),
          Row(children: [
            Stack(clipBehavior: Clip.none, children: [
              VinylDisc(size: 60, spinning: false, coverUrl: t.coverUrl, free: false, glow: false),
              Positioned(
                right: -4,
                bottom: -4,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(color: c.warning, shape: BoxShape.circle, border: Border.all(color: c.surface, width: 2)),
                  child: const Icon(Icons.lock_rounded, size: 12, color: Colors.white),
                ),
              ),
            ]),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Tu aimes ce titre ?', style: TextStyle(color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text('L’extrait gratuit de ${t.previewSec} secondes est terminé.', style: TextStyle(color: c.textSecondary, fontSize: 12.5, height: 1.3)),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          // Soutien de l'artiste
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: c.primary.withValues(alpha: .08), borderRadius: BorderRadius.circular(14), border: Border.all(color: c.primary.withValues(alpha: .35))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.favorite_rounded, size: 20, color: c.danger),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(style: TextStyle(color: c.textPrimary, fontSize: 12.5, height: 1.35), children: [
                    const TextSpan(text: 'Écoute '),
                    TextSpan(text: '« ${t.title} »', style: const TextStyle(fontWeight: FontWeight.w800)),
                    const TextSpan(text: ' en entier et soutiens '),
                    TextSpan(text: t.artist, style: const TextStyle(fontWeight: FontWeight.w800)),
                    if (forSale) ...[
                      const TextSpan(text: ' : '),
                      TextSpan(text: '${t.saleShare} pièces', style: const TextStyle(fontWeight: FontWeight.w800)),
                      const TextSpan(text: ' de ton achat vont directement à l’artiste.'),
                    ] else
                      const TextSpan(text: ' en l’utilisant dans ton prochain post.'),
                  ]),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          if (forSale) ...[
            SizedBox(
              height: 46,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(context, enough ? PreviewEnd.buy : PreviewEnd.topup),
                icon: Icon(enough ? Icons.library_add_rounded : Icons.add_circle_rounded, size: 20),
                label: Text(enough ? 'Acheter le titre · ${t.saleCoins} 🪙' : 'Recharger mes pièces', style: const TextStyle(fontWeight: FontWeight.w800)),
                style: FilledButton.styleFrom(backgroundColor: c.primary, foregroundColor: c.onPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              enough ? 'Ton solde : $balance pièces → ${balance - t.saleCoins} après' : '« ${t.title} » coûte ${t.saleCoins} pièces, il t’en reste $balance.',
              textAlign: TextAlign.center,
              style: TextStyle(color: enough ? c.textSecondary : c.warning, fontSize: 11.5, fontWeight: enough ? FontWeight.w500 : FontWeight.w700),
            ),
            const SizedBox(height: 10),
          ],
          if (canAd) ...[
            _outlined(c, Icons.ondemand_video_rounded, 'Écouter en entier avec une pub', () => Navigator.pop(context, PreviewEnd.ad)),
            const SizedBox(height: 8),
          ],
          if (t.sound != null) _outlined(c, Icons.videocam_rounded, use > 0 ? 'Créer un post avec ce son · $use 🪙' : 'Créer un post avec ce son', () => Navigator.pop(context, PreviewEnd.post)),
          const SizedBox(height: 4),
          TextButton(onPressed: () => Navigator.pop(context, PreviewEnd.later), child: Text('Plus tard', style: TextStyle(color: c.textSecondary, fontWeight: FontWeight.w800))),
        ]),
      ),
    );
  }

  Widget _outlined(AppColors c, IconData icon, String label, VoidCallback onTap) => SizedBox(
        height: 42,
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 19, color: c.primary),
          label: Text(label, textAlign: TextAlign.center, style: TextStyle(color: c.primary, fontWeight: FontWeight.w800, fontSize: 12.5)),
          style: OutlinedButton.styleFrom(side: BorderSide(color: c.primary.withValues(alpha: .5)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        ),
      );
}
