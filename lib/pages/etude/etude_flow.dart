import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../ads/ad_config.dart';
import '../../ads/ad_gate.dart';
import '../../ads/admob_service.dart';
import '../../ads/rewards_service.dart';
import '../../l10n/tr.dart';
import '../../providers/authProvider.dart';
import '../../services/coin_checkout.dart';
import '../../services/etude/etude_service.dart';
import '../../theme/app_colors.dart';
import '../quiz/widgets/quiz_widgets.dart';
import 'etude_play_page.dart';

/// Fenêtre de déblocage : payer en pièces, ou regarder des pubs (le nombre de pubs suit le prix en pièces).
/// Retourne true quand le contenu est débloqué.
Future<bool> showEtudeUnlock(BuildContext context, {required String item, required String title}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _UnlockSheet(item: item, title: title),
  );
  return ok == true;
}

class _UnlockSheet extends StatefulWidget {
  const _UnlockSheet({required this.item, required this.title});
  final String item, title;

  @override
  State<_UnlockSheet> createState() => _UnlockSheetState();
}

class _UnlockSheetState extends State<_UnlockSheet> {
  bool _busy = false;

  EtudeState get _s => EtudeService.instance.state.value ?? const EtudeState();

  @override
  void initState() {
    super.initState();
    AdmobService.loadRewarded();
    AdmobService.warmUpInterstitial(context.read<UserAuthProvider>().loginUserData);
  }

  Future<void> _pay() async {
    final price = _s.priceOf(widget.item);
    final user = context.read<UserAuthProvider>().loginUserData;
    if ((user.giftCoinsBalance ?? 0) < price) {
      await CoinCheckout.insufficient(context, price);
      return;
    }
    setState(() => _busy = true);
    try {
      await EtudeService.instance.unlock(widget.item, via: 'coins');
      if (!mounted) return;
      await CoinCheckout.refreshBalance(context);
      if (mounted) Navigator.pop(context, true);
    } on EtudeException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      if (e.code.contains('insuffisant')) {
        await CoinCheckout.refreshBalance(context);
        if (mounted) await CoinCheckout.insufficient(context, price);
      } else {
        quizToast(context, context.tr("Le paiement n'a pas pu être effectué. Tu n'as pas été débité."), error: true);
      }
    }
  }

  /// Pub plein écran : elle remplit la jauge d'un peu moins qu'une pub avec récompense.
  Future<void> _watchInterstitial() async {
    setState(() => _busy = true);
    final done = Completer<bool>();
    final shown = await AdmobService.showInterstitialNow(onDismissed: () => done.complete(true), onFailed: () {
      if (!done.isCompleted) done.complete(false);
    });
    if (!shown) {
      if (mounted) {
        setState(() => _busy = false);
        quizToast(context, context.tr("La pub n'est pas disponible pour le moment. Réessaie dans un instant."), error: true);
      }
      return;
    }
    final ok = await done.future;
    if (!mounted) return;
    if (!ok) {
      setState(() => _busy = false);
      return;
    }
    try {
      final unlocked = await EtudeService.instance.unlock(widget.item, via: 'ads', format: 'interstitial');
      if (!mounted) return;
      if (unlocked) {
        Navigator.pop(context, true);
      } else {
        setState(() => _busy = false);
        AdmobService.warmUpInterstitial(context.read<UserAuthProvider>().loginUserData);
      }
    } on EtudeException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      quizToast(
        context,
        e.code.contains('limite') ? context.tr("Tu as atteint la limite de pubs d'aujourd'hui. Reviens demain ou paie en pièces.") : context.tr("La pub n'a pas pu être comptée. Réessaie."),
        error: true,
      );
    }
  }

  /// Une pub avec récompense regardée remplit la jauge du contenu ; quand elle est pleine, il est débloqué.
  Future<void> _watch() async {
    setState(() => _busy = true);
    final ok = await AdmobService.watchRewarded(userId: EtudeService.instance.uid);
    if (!mounted) return;
    if (!ok) {
      setState(() => _busy = false);
      quizToast(context, context.tr("La pub n'est pas disponible pour le moment. Réessaie dans un instant."), error: true);
      return;
    }
    try {
      try {
        await RewardsService.recordView();
      } catch (_) {
        // vérification AdMob côté serveur : la pub est comptée par AdMob, parfois avec un petit délai
      }
      var done = false;
      for (var i = 0; i < 4 && !done; i++) {
        try {
          done = await EtudeService.instance.unlock(widget.item, via: 'ads');
          break;
        } on EtudeException catch (e) {
          if (!e.code.contains('NO_ADS') || i == 3) rethrow;
          await Future<void>.delayed(const Duration(seconds: 2));
        }
      }
      if (!mounted) return;
      if (done) {
        Navigator.pop(context, true);
      } else {
        setState(() => _busy = false);
      }
    } on EtudeException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      quizToast(
        context,
        e.code.contains('limite') ? context.tr("Tu as atteint la limite de pubs d'aujourd'hui. Reviens demain ou paie en pièces.") : context.tr("La pub n'a pas pu être comptée. Réessaie."),
        error: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = _s;
    final price = s.priceOf(widget.item);
    final paid = (s.adsPaid[widget.item] ?? 0).clamp(0, price);
    final left = price - paid;
    final user = context.read<UserAuthProvider>().loginUserData;
    final canRewarded = RewardsService.available(user);
    final canInterstitial = AdConfig.isMobile && AdConfig.current.interstitialEnabled && AdGate.canShowType(user, 'interstitial') && user.abonnement?.estGold != true;
    final canAds = canRewarded || canInterstitial;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(color: c.background, borderRadius: const BorderRadius.vertical(top: Radius.circular(24)), border: Border.all(color: c.border)),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 44, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: c.warning.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
              child: Icon(Icons.lock_open_rounded, color: c.warning),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.tr('Débloquer'), style: TextStyle(color: c.textSecondary, fontWeight: FontWeight.w700, fontSize: 12)),
                Text(widget.title, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w900, fontSize: 17)),
              ]),
            ),
          ]),
          const SizedBox(height: 18),
          QuizChunkyButton(
            label: context.tr('Payer {p}', {'p': CoinCheckout.coinsLabel(price)}),
            icon: Icons.monetization_on_rounded,
            color: c.primary,
            textColor: c.onPrimary,
            loading: _busy,
            onPressed: _pay,
          ),
          if (canAds) ...[
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: Divider(color: c.border)),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text(context.tr('ou'), style: TextStyle(color: c.textSecondary, fontWeight: FontWeight.w700))),
              Expanded(child: Divider(color: c.border)),
            ]),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: paid / price, minHeight: 10, backgroundColor: c.surfaceVariant, valueColor: AlwaysStoppedAnimation(c.accent)),
            ),
            const SizedBox(height: 6),
            Text(
              paid == 0
                  ? context.tr('Débloque avec des pubs : {a} avec récompense ou {b} plein écran', {'a': '${s.rewardedFor(price)}', 'b': '${s.interstitialFor(price)}'})
                  : context.tr('Jauge {p}/{n} : encore {a} pubs avec récompense ou {b} plein écran', {'p': '$paid', 'n': '$price', 'a': '${s.rewardedFor(left)}', 'b': '${s.interstitialFor(left)}'}),
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary, fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 10),
            if (canRewarded)
              QuizChunkyButton(
                label: context.tr('Pub avec récompense (+{n} pièces)', {'n': '${s.adValueCoins}'}),
                icon: Icons.play_circle_fill_rounded,
                color: c.accent,
                textColor: c.onAccent,
                loading: _busy,
                onPressed: _watch,
              ),
            if (canRewarded && canInterstitial) const SizedBox(height: 6),
            if (canInterstitial)
              QuizChunkyButton(
                label: context.tr('Pub plein écran (+{n} pièces)', {'n': '${s.interstitialValueCoins}'}),
                icon: Icons.fullscreen_rounded,
                color: c.surfaceVariant,
                textColor: c.textPrimary,
                loading: _busy,
                onPressed: _watchInterstitial,
              ),
          ],
          const SizedBox(height: 6),
          TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: Text(context.tr('Plus tard'), style: TextStyle(color: c.textSecondary))),
        ]),
      ),
    );
  }
}

/// Démarre une partie. Si le contenu est verrouillé, propose le déblocage puis réessaie.
/// Retourne true si la partie a été jouée jusqu'au bout.
Future<bool> etudeLaunch(
  BuildContext context, {
  required String kind,
  required String id,
  required String item,
  required String title,
}) async {
  EtudeStart? st;
  for (var attempt = 0; attempt < 2 && st == null; attempt++) {
    try {
      st = await EtudeService.instance.start(kind, id);
    } on EtudeException catch (e) {
      if (!context.mounted) return false;
      if (e.code.contains('LOCKED') && !e.code.contains('LEVEL') && !e.code.contains('PREVIOUS') && attempt == 0) {
        if (!await showEtudeUnlock(context, item: item, title: title)) return false;
        continue;
      }
      final msg = e.code.contains('CHAPTERS_TODO')
          ? context.tr('Termine d\'abord tous les chapitres.')
          : e.code.contains('CLASSES_TODO')
              ? context.tr('Valide d\'abord toutes les classes du parcours.')
              : e.code.contains('PREVIOUS_CLASS')
                  ? context.tr('Valide d\'abord la classe précédente.')
                  : e.code.contains('LEVEL_LOCKED')
                      ? context.tr('Réussis d\'abord le niveau précédent.')
                      : context.tr('Une erreur est survenue, réessaie.');
      quizToast(context, msg, error: true);
      return false;
    } catch (_) {
      if (context.mounted) quizToast(context, context.tr('Connexion impossible. Vérifie ta connexion.'), error: true);
      return false;
    }
  }
  if (st == null || !context.mounted) return false;
  final res = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => EtudePlayPage(start: st!)));
  return res == true;
}
