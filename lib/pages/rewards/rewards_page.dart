import 'package:afrotok/layout/centered_content.dart';
import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../ads/ad_config.dart';
import '../../ads/admob_service.dart';
import '../../ads/rewarded_ads.dart';
import '../../ads/rewards_service.dart';
import '../../l10n/tr.dart';
import '../../providers/authProvider.dart';
import '../../services/utils/abonnement_utils.dart';
import '../../theme/app_colors.dart';
import '../user/userAbonnementPage.dart';
import '../../widgets/offerwall_entry_card.dart';

/// Page « Récompenses » : on regarde des pubs plein écran pour avoir du Gold gratuit (passes de 30 minutes), exporter une création du Studio,
/// débloquer une fonction du Studio pour la journée, ou un bouclier de flamme. Il n'y a que deux plans : Gratuit et Gold. Le serveur décide de tout.
class RewardsPage extends StatefulWidget {
  /// [autoOffer] : identifiant d'une offre à lancer tout de suite à l'ouverture (ex. `coins_2` depuis la carte « cadeau » du fil).
  const RewardsPage({Key? key, this.autoOffer}) : super(key: key);
  final String? autoOffer;

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
    RewardsService.loadConfig(force: true).then((_) async {
      await _refresh();
      _maybeAutoRedeem();
    });
  }

  bool _autoStarted = false;

  void _maybeAutoRedeem() {
    final id = widget.autoOffer;
    if (id == null || _autoStarted || !mounted) return;
    _autoStarted = true;
    final offer = RewardsService.visibleOffers(_auth.loginUserData).where((o) => o.id == id).toList();
    if (offer.isNotEmpty) _redeem(offer.first);
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
    if (e is ApiException && e.message.isNotEmpty) return e.message;
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
        final earned = await RewardedAds.watch(userId: _uid); // AdMob d'abord, Appodeal en renfort s'il n'a aucune pub
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
    final showUpsell = !admin;

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
            // Gold : aucune pub, mais le travail rémunéré reste proposé (il ne dépend pas des pubs)
            ? ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  const OfferwallEntryCard(),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(context.tr('Tu es Gold : aucune pub, tout est déjà débloqué.'),
                        textAlign: TextAlign.center, style: TextStyle(color: colors.textSecondary, fontSize: 15, height: 1.4)),
                  ),
                ],
              )
            : _loading
                ? Center(child: CircularProgressIndicator(color: colors.primary))
                : RefreshIndicator(
                    color: colors.primary,
                    onRefresh: _refresh,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                      children: [
                        const OfferwallEntryCard(),
                        _goldBanner(colors),
                        _progressCard(colors, admin),
                        const SizedBox(height: 12),
                        for (final o in offers) _offerCard(o, colors, admin, remainingAds),
                        _featuresSection(colors, admin, remainingAds),
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
        Icon(Icons.workspace_premium_rounded, color: colors.accentText, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.tr('Passer Gold : {p} F par mois', {'p': RewardsService.goldPriceMonth}), style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(height: 2),
            Text(context.tr('Sans pub, toutes les fonctions du Studio et l\'export libres, tout le temps.'),
                style: TextStyle(color: colors.textSecondary, fontSize: 12, height: 1.3)),
          ]),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AbonnementScreen())),
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.accentText,
            side: BorderSide(color: colors.accent),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          ),
          child: Text(context.tr('Voir'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
        ),
      ]),
    );
  }

  /// Où j'en suis avec le Gold gratuit : passe en cours (jusqu'à quelle heure) ou combien de pubs pour la prochaine.
  Widget _goldBanner(AppColors colors) {
    final until = RewardsService.goldUntil;
    final active = RewardsService.goldActive && RewardsService.goldSource == 'pass' && until != null;
    final left = active ? until.difference(DateTime.now()) : Duration.zero;
    final n = RewardsService.nextPassAds;
    final text = active
        ? context.tr('Gold gratuit actif : encore {m} min', {'m': left.inMinutes.clamp(0, 999)})
        : (n == null
            ? context.tr('Plus de passe Gold gratuite aujourd\'hui. Reviens demain, ou passe Gold.')
            : context.tr('{n} pubs plein écran = {m} minutes de Gold gratuit', {'n': n, 'm': RewardsService.passMinutes}));
    return Container(
      key: const ValueKey('gold_banner'),
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: colors.accent, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Icon(Icons.workspace_premium_rounded, color: colors.onAccent, size: 30),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.tr('Gold gratuit'), style: TextStyle(color: colors.onAccent, fontWeight: FontWeight.w900, fontSize: 15)),
            const SizedBox(height: 2),
            Text(text, style: TextStyle(color: colors.onAccent, fontSize: 12.5, height: 1.3)),
            Text(context.tr('Passes aujourd\'hui : {a}/{b}', {'a': RewardsService.passesToday, 'b': RewardsService.maxPasses}), style: TextStyle(color: colors.onAccent.withValues(alpha: .75), fontSize: 11.5)),
          ]),
        ),
      ]),
    );
  }

  /// Fonctions du Studio : chacune se débloque pour la journée avec quelques pubs (ou est incluse dans Gold / une passe).
  Widget _featuresSection(AppColors colors, bool admin, int remainingAds) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(2, 14, 2, 6),
        child: Text(context.tr('Fonctions du Studio'), style: TextStyle(color: colors.textPrimary, fontSize: 15, fontWeight: FontWeight.w900)),
      ),
      for (final f in RewardsService.featureCatalog)
        if (RewardsService.dynamicOffer('feature:${f.$1}') case final o?)
          _offerCard(o, colors, admin, remainingAds, unlocked: RewardsService.featureUnlocked(f.$1)),
    ]);
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
                  style: TextStyle(color: colors.accentText, fontWeight: FontWeight.w800, fontSize: 11)),
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

  Widget _offerCard(RewardOffer o, AppColors colors, bool admin, int remainingAds, {bool unlocked = false}) {
    final claimed = _status.claims[o.id] ?? 0;
    final capReached = !admin && (unlocked || claimed >= o.cap);
    final needed = (o.ads - _status.pending).clamp(0, o.ads);
    final dayLimit = !admin && needed > remainingAds;
    final busy = _busyOffer == o.id;
    final disabled = _busyOffer != null || capReached || dayLimit;
    final title = context.tr(o.title);
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
          child: Icon(o.icon, color: o.premium ? colors.accentText : colors.primary, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(height: 2),
            Text(
              unlocked ? context.tr('Débloquée aujourd\'hui') : (capReached ? context.tr('Limite du jour atteinte') : context.tr(o.desc)),
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
