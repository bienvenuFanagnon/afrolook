import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../ads/ad_config.dart';
import '../../../ads/admob_service.dart';
import '../../../ads/rewards_service.dart';
import '../../../l10n/tr.dart';
import '../../../providers/authProvider.dart';
import '../../../theme/app_colors.dart';

/// Carte « pub bonus » des groupes officiels : le membre qui a lu les infos peut regarder une pub récompensée
/// (au choix) pour gagner des pièces cadeau. Passe par le même circuit que la page Récompenses
/// (offre `coins_2`) : mêmes plafonds par jour et par semaine, décidés par le serveur.
///
/// N'occupe aucune place tant que la récompense n'est pas disponible (Gold, plafond atteint, pubs coupées…)
/// ni avant que le membre ait lu (arrivé en bas du fil) ou patienté [AdConfig.groupRewardDelaySeconds] secondes.
class GroupRewardBar extends StatefulWidget {
  const GroupRewardBar({Key? key, required this.readToBottom}) : super(key: key);

  /// Vrai quand le membre est arrivé en bas du fil en le faisant défiler.
  final bool readToBottom;

  @override
  State<GroupRewardBar> createState() => _GroupRewardBarState();
}

class _GroupRewardBarState extends State<GroupRewardBar> {
  static const _offerId = 'coins_2';

  RewardsStatus _status = RewardsStatus.empty;
  bool _loaded = false;
  bool _delayElapsed = false;
  bool _busy = false;
  Timer? _timer;

  String get _uid => context.read<UserAuthProvider>().loginUserData.id ?? '';

  @override
  void initState() {
    super.initState();
    final delay = AdConfig.current.groupRewardDelaySeconds;
    if (delay == 0) {
      _delayElapsed = true;
    } else {
      _timer = Timer(Duration(seconds: delay), () {
        if (mounted) setState(() => _delayElapsed = true);
      });
    }
    _init();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    if (!AdConfig.current.enabled || !AdConfig.current.groupRewardEnabled) return;
    await RewardsService.loadConfig();
    AdmobService.loadRewarded();
    await _refresh();
  }

  Future<void> _refresh() async {
    if (_uid.isEmpty) return;
    final s = await RewardsService.status(_uid);
    if (mounted) {
      setState(() {
        _status = s;
        _loaded = true;
      });
    }
  }

  void _say(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(t), duration: const Duration(seconds: 3)));
  }

  Future<void> _watch() async {
    if (_busy) return;
    setState(() => _busy = true);
    final auth = context.read<UserAuthProvider>();
    try {
      final ok = await RewardsService.watchAndClaim(_offerId, _uid);
      if (!mounted) return;
      if (ok) {
        await auth.getCurrentUser(_uid);
        _say(tr('{n} pièces ajoutées ! 🎉', {'n': RewardsService.coinOfferCoins}));
      } else {
        _say(tr('Aucune vidéo disponible pour le moment, réessaie dans un instant.'));
      }
    } catch (e) {
      if (mounted) {
        _say(e is FirebaseFunctionsException && (e.message ?? '').isNotEmpty
            ? e.message!
            : tr('Impossible d\'obtenir la récompense pour le moment.'));
      }
    } finally {
      await _refresh();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserAuthProvider>().loginUserData;
    if (!_loaded || !(widget.readToBottom || _delayElapsed)) return const SizedBox.shrink();
    if (!AdConfig.current.groupRewardEnabled || !RewardsService.available(user)) return const SizedBox.shrink();
    final offer = RewardsService.offerById(_offerId);
    if (offer == null || !RewardsService.canClaimToday(_status, offer)) return const SizedBox.shrink();

    final colors = AppColors.of(context);
    final coins = RewardsService.coinOfferCoins;
    final left = offer.cap <= 0 ? null : (offer.cap - (_status.claims[_offerId] ?? 0)).clamp(0, offer.cap);
    return Container(
      color: colors.background,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFF5C542).withOpacity(0.4)),
          ),
          child: Row(children: [
            const Icon(Icons.card_giftcard_rounded, color: Color(0xFFF5C542), size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr('Pub bonus'), style: TextStyle(color: colors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                Text(tr('Une pub = {n} pièces', {'n': coins}),
                    style: TextStyle(color: colors.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
              ]),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _busy ? null : _watch,
              icon: _busy
                  ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: colors.onPrimary))
                  : const Icon(Icons.play_arrow_rounded, size: 18),
              label: Text(tr('Regarder'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ]),
        ),
        if (left != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              left == 1 ? tr('Il te reste 1 pub bonus aujourd\'hui') : tr('Il te reste {n} pubs bonus aujourd\'hui', {'n': left}),
              style: TextStyle(color: colors.textSecondary, fontSize: 11),
            ),
          ),
      ]),
    );
  }
}
