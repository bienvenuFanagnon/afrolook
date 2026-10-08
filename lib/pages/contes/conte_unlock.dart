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
import '../../services/contes/contes_service.dart';
import 'conte_style.dart';

/// Fenêtre « La suite est scellée » : pubs (la jauge se remplit pub après pub), pièces, ou lecture offerte quand aucune
/// pub n'est disponible (quota par jour). Le lecteur n'est jamais bloqué. Retourne true quand le conte est débloqué.
Future<bool> showConteUnlock(BuildContext context, {required ConteCard card}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _ConteUnlockSheet(card: card),
  );
  return ok == true;
}

class _ConteUnlockSheet extends StatefulWidget {
  const _ConteUnlockSheet({required this.card});
  final ConteCard card;

  @override
  State<_ConteUnlockSheet> createState() => _ConteUnlockSheetState();
}

class _ConteUnlockSheetState extends State<_ConteUnlockSheet> with EtudeAdBypass {
  bool _busy = false;
  // une pub n'a pas pu être affichée : on propose alors la lecture offerte (ou les pièces)
  bool _adFailed = false;

  ContesState get _s => ContesService.instance.state.value ?? const ContesState();
  String get _item => 'st:${widget.card.id}';

  @override
  void initState() {
    super.initState();
    AdmobService.loadRewarded();
    AdmobService.warmUpInterstitial(context.read<UserAuthProvider>().loginUserData);
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg, style: ConteStyle.body(15, color: ConteStyle.parch)), backgroundColor: ConteStyle.ink, behavior: SnackBarBehavior.floating));
  }

  Future<void> _pay(String item, int price) async {
    final user = context.read<UserAuthProvider>().loginUserData;
    if ((user.giftCoinsBalance ?? 0) < price) {
      await CoinCheckout.insufficient(context, price);
      return;
    }
    setState(() => _busy = true);
    try {
      final unlocked = await ContesService.instance.unlock(item, via: 'coins');
      if (!mounted) return;
      await CoinCheckout.refreshBalance(context);
      if (mounted) Navigator.pop(context, unlocked);
    } on ConteException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      if (e.code.toLowerCase().contains('insuffisant')) {
        await CoinCheckout.refreshBalance(context);
        if (mounted) await CoinCheckout.insufficient(context, price);
      } else {
        _toast(context.tr("Le paiement n'a pas pu être effectué. Tu n'as pas été débité."));
      }
    } catch (_) {
      if (mounted) setState(() => _busy = false);
      _toast(context.tr('Connexion impossible. Vérifie ta connexion.'));
    }
  }

  /// Lecture offerte : quand aucune pub n'est disponible, le lecteur lit quand même (nombre limité par jour).
  Future<void> _free() async {
    setState(() => _busy = true);
    try {
      final unlocked = await ContesService.instance.unlock(_item, via: 'free');
      if (mounted) Navigator.pop(context, unlocked);
    } on ConteException {
      if (!mounted) return;
      setState(() => _busy = false);
      await ContesService.instance.loadState().catchError((_) => const ContesState());
      if (mounted) setState(() {});
      _toast(context.tr("Tes lectures offertes d'aujourd'hui sont utilisées. Reviens demain, ou lis avec des pièces."));
    }
  }

  Future<void> _watchInterstitial() async {
    setState(() => _busy = true);
    final done = Completer<bool>();
    final shown = await AdmobService.showInterstitialNow(onDismissed: () => done.complete(true), onFailed: () {
      if (!done.isCompleted) done.complete(false);
    });
    if (!shown) {
      if (mounted) setState(() {
        _busy = false;
        _adFailed = true;
      });
      return;
    }
    final ok = await done.future;
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _busy = false;
        _adFailed = true;
      });
      return;
    }
    try {
      final unlocked = await ContesService.instance.unlock(_item, via: 'ads', format: 'interstitial');
      if (!mounted) return;
      if (unlocked) {
        Navigator.pop(context, true);
      } else {
        setState(() => _busy = false);
        AdmobService.warmUpInterstitial(context.read<UserAuthProvider>().loginUserData);
      }
    } on ConteException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(e.code.toLowerCase().contains('imite') ? context.tr("Tu as atteint la limite de pubs d'aujourd'hui. Reviens demain ou paie en pièces.") : context.tr("La pub n'a pas pu être comptée. Réessaie."));
    }
  }

  /// Une pub avec récompense regardée remplit la jauge du conte ; quand elle est pleine, il est débloqué.
  Future<void> _watch() async {
    setState(() => _busy = true);
    final ok = await AdmobService.watchRewarded(userId: ContesService.instance.uid);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _busy = false;
        _adFailed = true;
      });
      return;
    }
    try {
      try {
        await RewardsService.recordView();
      } catch (_) {
        // la pub est vérifiée par AdMob côté serveur, parfois avec un petit délai
      }
      var done = false;
      for (var i = 0; i < 4 && !done; i++) {
        try {
          done = await ContesService.instance.unlock(_item, via: 'ads');
          break;
        } on ConteException catch (e) {
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
    } on ConteException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(e.code.toLowerCase().contains('imite') ? context.tr("Tu as atteint la limite de pubs d'aujourd'hui. Reviens demain ou paie en pièces.") : context.tr("La pub n'a pas pu être comptée. Réessaie."));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final cfg = s.cfg;
    final price = cfg.priceOf(widget.card);
    final paid = (s.adsPaid[_item] ?? 0).clamp(0, price);
    final left = price - paid;
    final user = context.read<UserAuthProvider>().loginUserData;
    final canRewarded = RewardsService.available(user);
    final canInterstitial = AdConfig.isMobile && AdConfig.current.interstitialEnabled && AdGate.canShowType(user, 'interstitial');
    // pas de pub possible (non disponible, ou pub qui vient d'échouer) : lecture offerte, sinon pièces
    final canAds = (canRewarded || canInterstitial) && !_adFailed;
    final collection = ContesService.instance.cachedCatalog.collection(widget.card.collectionId);
    final packPrice = collection?.price ?? cfg.priceRecueil;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      child: Parchment(
        seed: 11,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Center(child: Container(width: 44, height: 4, decoration: BoxDecoration(color: ConteStyle.ink2.withOpacity(.5), borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 14),
              Center(
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: const BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(center: Alignment(-.3, -.4), colors: [Color(0xFFE3694A), Color(0xFF8E2D18)]), boxShadow: [BoxShadow(color: Color(0x66000000), blurRadius: 6, offset: Offset(0, 3))]),
                  child: const Icon(Icons.lock_rounded, color: Color(0xFFF7D9A8), size: 26),
                ),
              ),
              const SizedBox(height: 10),
              Text(context.tr('Le sceau garde la suite'), textAlign: TextAlign.center, style: ConteStyle.title(18)),
              const SizedBox(height: 4),
              Text(widget.card.title, textAlign: TextAlign.center, style: ConteStyle.body(17, style: FontStyle.italic, color: ConteStyle.ink2)),
              const SizedBox(height: 14),
              const ConteOrnament(),
              const SizedBox(height: 14),
              if (canAds) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(value: price == 0 ? 0 : paid / price, minHeight: 10, backgroundColor: Colors.black12, valueColor: const AlwaysStoppedAnimation(ConteStyle.gold)),
                ),
                const SizedBox(height: 6),
                Text(
                  paid == 0
                      ? context.tr('Lis la suite avec des pubs : {a} avec récompense ou {b} plein écran', {'a': '${cfg.rewardedFor(price)}', 'b': '${cfg.interstitialFor(price)}'})
                      : context.tr('Jauge {p}/{n} : encore {a} pubs avec récompense ou {b} plein écran', {'p': '$paid', 'n': '$price', 'a': '${cfg.rewardedFor(left)}', 'b': '${cfg.interstitialFor(left)}'}),
                  textAlign: TextAlign.center,
                  style: ConteStyle.body(15, color: ConteStyle.ink2),
                ),
                const SizedBox(height: 10),
                if (canRewarded) ConteButton(label: context.tr('Regarder une pub (+{n} pièces)', {'n': '${cfg.adValueCoins}'}), icon: Icons.play_circle_fill_rounded, kind: ConteButtonKind.gold, loading: _busy, onTap: _watch),
                if (canRewarded && canInterstitial) const SizedBox(height: 8),
                if (canInterstitial) ConteButton(label: context.tr('Pub plein écran (+{n} pièces)', {'n': '${cfg.interstitialValueCoins}'}), icon: Icons.fullscreen_rounded, kind: ConteButtonKind.outline, loading: _busy, onTap: _watchInterstitial),
                const SizedBox(height: 14),
                _or(),
                const SizedBox(height: 10),
              ] else ...[
                Text(
                  _adFailed ? context.tr("Aucune pub n'est disponible pour le moment. Tu peux quand même lire la suite.") : context.tr('Lis la suite maintenant.'),
                  textAlign: TextAlign.center,
                  style: ConteStyle.body(16, color: ConteStyle.ink2),
                ),
                const SizedBox(height: 10),
                if (s.freeLeft > 0) ...[
                  ConteButton(
                    label: context.tr('Lecture offerte ({n} restante{p} aujourd\'hui)', {'n': '${s.freeLeft}', 'p': s.freeLeft > 1 ? 's' : ''}),
                    icon: Icons.card_giftcard_rounded,
                    kind: ConteButtonKind.gold,
                    loading: _busy,
                    onTap: _free,
                  ),
                  const SizedBox(height: 8),
                  _or(),
                  const SizedBox(height: 8),
                ],
              ],
              ConteButton(label: context.tr('Lire avec {p}', {'p': context.tr('{a} pièces', {'a': CoinCheckout.fmt(price)})}), icon: Icons.monetization_on_rounded, loading: _busy, onTap: () => _pay(_item, price)),
              const SizedBox(height: 8),
              if (collection != null && collection.count > 1)
                ConteButton(
                  label: context.tr('Tout le recueil ({n} contes) : {p} pièces', {'n': '${collection.count}', 'p': CoinCheckout.fmt(packPrice)}),
                  icon: Icons.auto_stories_rounded,
                  kind: ConteButtonKind.outline,
                  compact: true,
                  loading: _busy,
                  onTap: () => _pay('co:${collection.id}', packPrice),
                ),
              if (collection != null && collection.count > 1) const SizedBox(height: 8),
              if (!s.passActive)
                ConteButton(
                  label: context.tr('Pass Veillée {h} h : {p} pièces', {'h': '${cfg.passHours}', 'p': CoinCheckout.fmt(cfg.pricePass)}),
                  icon: Icons.nights_stay_rounded,
                  kind: ConteButtonKind.outline,
                  compact: true,
                  loading: _busy,
                  onTap: () => _pay('pass', cfg.pricePass),
                ),
              const SizedBox(height: 4),
              ConteButton(label: context.tr('Plus tard'), kind: ConteButtonKind.quiet, compact: true, onTap: _busy ? null : () => Navigator.pop(context, false)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _or() => Row(children: [
        Expanded(child: Container(height: 1, color: ConteStyle.ink2.withOpacity(.4))),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text(context.tr('ou'), style: ConteStyle.label(13))),
        Expanded(child: Container(height: 1, color: ConteStyle.ink2.withOpacity(.4))),
      ]);
}
