import 'package:afrotok/layout/centered_content.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../ads/ad_config.dart';
import '../../ads/admob_service.dart';
import '../../ads/rewards_service.dart';
import '../../l10n/tr.dart';
import '../../providers/authProvider.dart';
import '../../services/utils/abonnement_utils.dart';
import '../../theme/app_colors.dart';
import '../user/userAbonnementPage.dart';

/// Page « Récompenses » : on regarde des pubs (au choix) pour débloquer du Premium temporaire,
/// une journée sans pub, des pièces cadeau ou un bouclier de flamme. Le serveur décide de tout.
class RewardsPage extends StatefulWidget {
  const RewardsPage({Key? key}) : super(key: key);

  @override
  State<RewardsPage> createState() => _RewardsPageState();
}

class _RewardsPageState extends State<RewardsPage> {
  RewardsStatus _status = RewardsStatus.empty;
  bool _loading = true;
  String? _busyOffer;
  String _progress = '';

  UserAuthProvider get _auth => Provider.of<UserAuthProvider>(context, listen: false);
  String get _uid => _auth.loginUserData.id ?? '';

  @override
  void initState() {
    super.initState();
    if (AdConfig.current.enabled) AdmobService.loadRewarded();
    RewardsService.loadConfig(force: true).then((_) => _refresh());
  }

  Future<void> _refresh() async {
    if (_uid.isEmpty) return;
    final s = await RewardsService.status(_uid);
    if (mounted) setState(() {
      _status = s;
      _loading = false;
    });
  }

  void _say(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(t), duration: const Duration(seconds: 3)));
  }

  /// Attend que le serveur (vérification AdMob) ait compté la pub : jusqu'à ~12 s.
  Future<int> _waitServerPending(int target) async {
    var pending = _status.pending;
    for (var i = 0; i < 8; i++) {
      final s = await RewardsService.status(_uid);
      pending = s.pending;
      if (pending >= target) return pending;
      await Future<void>.delayed(const Duration(milliseconds: 1500));
    }
    return pending;
  }

  String _error(Object e) {
    if (e is FirebaseFunctionsException && (e.message ?? '').isNotEmpty) return e.message!;
    return context.tr('Impossible d\'obtenir la récompense pour le moment.');
  }

  Future<void> _redeem(RewardOffer o) async {
    if (_busyOffer != null) return;
    setState(() => _busyOffer = o.id);
    try {
      var pending = _status.pending;
      while (pending < o.ads) {
        if (mounted) {
          setState(() => _progress = context.tr('Pub {i} sur {n}', {'i': pending + 1, 'n': o.ads}));
        }
        final earned = await AdmobService.watchRewarded(userId: _uid);
        if (!mounted) return;
        if (!earned) {
          _say(context.tr('Aucune vidéo disponible pour le moment, réessaie dans un instant.'));
          break;
        }
        if (AdConfig.current.ssvEnabled) {
          pending = await _waitServerPending(pending + 1);
        } else {
          pending = (await RewardsService.recordView()) ?? pending + 1;
        }
      }
      await _refresh();
      if (pending >= o.ads) {
        await RewardsService.claim(o.id);
        await _auth.getCurrentUser(_uid);
        if (mounted) _say(context.tr('Récompense obtenue ! 🎉'));
      }
    } catch (e) {
      if (mounted) _say(_error(e));
    } finally {
      await _refresh();
      if (mounted) setState(() {
        _busyOffer = null;
        _progress = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final user = context.watch<UserAuthProvider>().loginUserData;
    final isGold = user.abonnement?.estGold == true && !AbonnementUtils.isAdmin(user.role);
    final offers = RewardsService.visibleOffers(user);
    final admin = AbonnementUtils.isAdmin(user.role);
    final remainingAds = RewardsService.maxAdsPerDay - _status.watched;
    final showUpsell = !admin && user.abonnement?.estPremium != true || (user.abonnement?.methodePaiement == 'pubs' && !admin);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        title: Text('🎁 ${context.tr('Récompenses')}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      ),
      body: CenteredContent(
        child: isGold
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(context.tr('Tu es Gold : aucune pub, tout est déjà débloqué.'),
                      textAlign: TextAlign.center, style: TextStyle(color: colors.textSecondary, fontSize: 15, height: 1.4)),
                ),
              )
            : _loading
                ? Center(child: CircularProgressIndicator(color: colors.primary))
                : RefreshIndicator(
                    color: colors.primary,
                    onRefresh: _refresh,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                      children: [
                        _progressCard(colors, admin),
                        const SizedBox(height: 12),
                        for (final o in offers) _offerCard(o, colors, admin, remainingAds),
                        if (showUpsell) _upsellCard(colors),
                      ],
                    ),
                  ),
      ),
    );
  }

  /// Invitation à s'abonner : le Premium gratuit par pubs est limité, l'abonnement ne l'est pas.
  Widget _upsellCard(AppColors colors) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.accent.withOpacity(0.5)),
      ),
      child: Row(children: [
        Icon(Icons.workspace_premium_rounded, color: colors.accent, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.tr('Envie de plus ?'), style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(height: 2),
            Text(context.tr('Avec un abonnement : pas de limite par jour ou par semaine, et tout le temps disponible.'),
                style: TextStyle(color: colors.textSecondary, fontSize: 12, height: 1.3)),
          ]),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AbonnementScreen())),
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.accent,
            side: BorderSide(color: colors.accent),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          ),
          child: Text(context.tr('Voir'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
        ),
      ]),
    );
  }

  Widget _progressCard(AppColors colors, bool admin) {
    final watched = _status.watched.clamp(0, RewardsService.maxAdsPerDay);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(
              context.tr('Pubs regardées aujourd\'hui : {n}/{max}', {'n': admin ? _status.watched : watched, 'max': RewardsService.maxAdsPerDay}),
              style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          if (_status.pending > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: colors.accent.withOpacity(0.18), borderRadius: BorderRadius.circular(10)),
              child: Text(context.tr('Pubs en réserve : {n}', {'n': _status.pending}),
                  style: TextStyle(color: colors.accent, fontWeight: FontWeight.w800, fontSize: 11)),
            ),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: watched / RewardsService.maxAdsPerDay,
            minHeight: 7,
            backgroundColor: colors.surfaceVariant,
            valueColor: AlwaysStoppedAnimation(colors.accent),
          ),
        ),
      ]),
    );
  }

  Widget _offerCard(RewardOffer o, AppColors colors, bool admin, int remainingAds) {
    final claimed = _status.claims[o.id] ?? 0;
    final capReached = !admin && claimed >= o.cap;
    final needed = (o.ads - _status.pending).clamp(0, o.ads);
    final dayLimit = !admin && needed > remainingAds;
    final busy = _busyOffer == o.id;
    final disabled = _busyOffer != null || capReached || dayLimit;
    final title = o.premium ? context.tr('Premium {h} heures', {'h': o.hours}) : context.tr(o.title);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(color: colors.surfaceVariant, borderRadius: BorderRadius.circular(11)),
          child: Icon(o.icon, color: o.premium ? colors.accent : colors.primary, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(height: 2),
            Text(
              capReached ? context.tr('Limite du jour atteinte') : context.tr(o.desc),
              style: TextStyle(color: colors.textSecondary, fontSize: 12, height: 1.3),
            ),
            if (busy && _progress.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_progress, style: TextStyle(color: colors.primary, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
          ]),
        ),
        const SizedBox(width: 8),
        Opacity(
          opacity: disabled && !busy ? 0.45 : 1,
          child: ElevatedButton(
            onPressed: disabled ? null : () => _redeem(o),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              disabledBackgroundColor: colors.primary,
              disabledForegroundColor: colors.onPrimary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            ),
            child: busy
                ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: colors.onPrimary))
                : Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(context.tr('Regarder'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                    Text(context.tr(o.ads > 1 ? '{n} pubs' : '{n} pub', {'n': o.ads}),
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600)),
                  ]),
          ),
        ),
      ]),
    );
  }
}
