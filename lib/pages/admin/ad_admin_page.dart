import 'package:afrotok/services/read_meter.dart';
import 'package:afrotok/ads/ad_config.dart';
import 'package:afrotok/ads/ad_gate.dart';
import 'package:afrotok/ads/admob_service.dart';
import 'package:afrotok/ads/appodeal_service.dart';
import 'package:afrotok/ads/ad_banner.dart';
import 'package:afrotok/ads/appodeal_widgets.dart';
import 'package:afrotok/ads/admob_widgets.dart';
import 'package:afrotok/ads/rewards_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:afrotok/layout/centered_content.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Outils admin des publicités : état de la configuration (Appodeal pour les bannières, AdMob pour le reste), inspecteur, essais de chaque format.
/// (L'admin voit toujours les pubs, même Gold, pour vérifier que tout fonctionne.)
class AdAdminPage extends StatefulWidget {
  const AdAdminPage({Key? key}) : super(key: key);

  @override
  State<AdAdminPage> createState() => _AdAdminPageState();
}

class _AdAdminPageState extends State<AdAdminPage> {
  String _status = "En attente d'action...";
  Map<String, dynamic> _todayStats = {};

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  /// Récompenses accordées aujourd'hui (AdRewardStats, jour UTC) : pour surveiller l'effet sur les abonnements.
  Future<void> _loadStats() async {
    try {
      final day = DateTime.now().toUtc().toIso8601String().substring(0, 10).replaceAll('-', '');
      final doc = await FirebaseFirestore.instance.collection('AdRewardStats').doc(day).getM('ad_admin_page.dart:36');
      if (mounted) setState(() => _todayStats = doc.data() ?? {});
    } catch (_) {}
  }

  Future<void> _reload() async {
    await AdConfig.load(force: true);
    await AdmobService.init();
    if (mounted) setState(() => _status = 'Configuration rechargée');
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final user = context.watch<UserAuthProvider>().loginUserData;
    final c = AdConfig.current;
    Widget row(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Expanded(child: Text(k, style: TextStyle(color: colors.textSecondary, fontSize: 13))),
            Text(v, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
          ]),
        );
    Widget btn(String label, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(backgroundColor: colors.primary, foregroundColor: colors.onPrimary),
              child: Text(label),
            ),
          ),
        );
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        title: const Text('Publicités (Appodeal + AdMob)'),
      ),
      body: CenteredContent(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.border),
              ),
              child: Column(children: [
                row('Plateforme', AdConfig.platform),
                row('Pubs activées (Firestore AppConfig/ads)', c.enabled ? 'oui' : 'non'),
                row('Pourcentage d\'utilisateurs', '${c.rolloutPercent} %'),
                row('Mode', c.testMode ? 'TEST' : 'PRODUCTION'),
                row('SDK prêt (consentement)', AdmobService.ready.value ? 'oui' : 'non'),
                row('Moi : pubs autorisées', AdGate.canShowAdmob(user) ? 'oui' : 'non'),
                row('Emplacement natif', c.unit('native').isEmpty ? 'manquant' : 'ok'),
                row('Emplacement bannière', c.unit('banner').isEmpty ? 'manquant' : 'ok'),
                row('Emplacement plein écran', c.unit('interstitial').isEmpty ? 'manquant' : 'ok'),
                row('Emplacement récompensée', c.unit('rewarded').isEmpty ? 'manquant' : 'ok'),
                const Divider(height: 18),
                row('Bannières confiées à', AppodealService.bannersViaAppodeal ? 'Appodeal (médiation)' : (c.bannerProvider == 'appodeal' ? 'AdMob direct (Appodeal pas encore activé sur iPhone)' : 'AdMob en direct')),
                ListenableBuilder(
                  listenable: Listenable.merge([
                    AppodealService.ready,
                    AppodealService.bannerLoaded,
                    AppodealService.bannerFailed,
                    AppodealService.mrecLoaded,
                    AppodealService.mrecFailed,
                    AppodealService.lastNetwork,
                  ]),
                  builder: (context, _) => Column(children: [
                    row('Appodeal prêt', AppodealService.ready.value ? 'oui' : 'non'),
                    row('Appodeal : mode', AppodealService.useTestAds ? 'TEST (développement)' : 'PRODUCTION'),
                    row('Appodeal : clé', '…${AppodealService.appKey.substring(AppodealService.appKey.length - 6)}'),
                    row('Bannières chargées / échecs', '${AppodealService.bannerLoaded.value} / ${AppodealService.bannerFailed.value}'),
                    row('Grands formats chargés / échecs', '${AppodealService.mrecLoaded.value} / ${AppodealService.mrecFailed.value}'),
                    row('Repli bannières vers AdMob direct', AppodealService.skipBanners ? 'ACTIF (Appodeal ne remplit pas, nouvel essai dans 10 min max)' : 'non'),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('Dernier réseau ayant servi une pub : ${AppodealService.lastNetwork.value}',
                            style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                      ),
                    ),
                    if (AppodealService.lastError != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('Dernière erreur Appodeal : ${AppodealService.lastError}', style: TextStyle(color: colors.warning, fontSize: 12)),
                        ),
                      ),
                  ]),
                ),
                const SizedBox(height: 4),
                Text("Changer de fournisseur sans mise à jour : node tools/ads/set_config.js '{\"bannerProvider\":\"admob\"}' (ou \"appodeal\").", style: TextStyle(color: colors.textSecondary, fontSize: 11.5)),
              ]),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.border),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Récompenses accordées aujourd\'hui (jour UTC)',
                    style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
                const SizedBox(height: 6),
                if (((_todayStats['claims'] as Map?) ?? const {}).isEmpty)
                  Text('Aucune pour le moment', style: TextStyle(color: colors.textSecondary, fontSize: 12))
                else
                  for (final e in (_todayStats['claims'] as Map).entries) row('${e.key}', '${e.value}'),
                row('Pubs échangées', '${_todayStats['adsSpent'] ?? 0}'),
              ]),
            ),
            const SizedBox(height: 14),
            btn('Recharger la configuration', () async {
              await RewardsService.loadConfig(force: true);
              await _loadStats();
              await AppodealService.init();
              await _reload();
            }),
            btn('Ouvrir l\'inspecteur AdMob', AdmobService.openInspector),
            const SizedBox(height: 4),
            Text('Essais Appodeal (vrais réseaux, comme pour les utilisateurs)', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
            const SizedBox(height: 6),
            btn('Essayer Appodeal : plein écran', () => AppodealService.testFullScreen(rewarded: false)),
            btn('Essayer Appodeal : récompensée', () => AppodealService.testFullScreen(rewarded: true)),
            ValueListenableBuilder<List<String>>(
              valueListenable: AppodealService.testLog,
              builder: (context, lines, _) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  lines.isEmpty ? 'Journal des essais Appodeal : aucun essai pour l\'instant' : lines.join('\n'),
                  style: TextStyle(color: colors.textSecondary, fontSize: 11.5),
                ),
              ),
            ),
            btn('Essayer la pub plein écran', () async {
              AdmobService.preloadInterstitial();
              final ok = await AdmobService.showInterstitialNow(
                onFailed: () => setState(() => _status = 'Plein écran indisponible : ${AdmobService.lastErrors['plein écran'] ?? 'en chargement, réessaie dans quelques secondes'}'),
              );
              if (ok) setState(() => _status = 'Plein écran affiché');
            }),
            btn('Essayer la pub récompensée', () {
              AdmobService.loadRewarded();
              final ok = AdmobService.showRewarded(onEarned: () => setState(() => _status = 'Récompense obtenue'));
              if (!ok) setState(() => _status = 'Récompensée indisponible : ${AdmobService.lastErrors['récompensée'] ?? 'en chargement, réessaie dans quelques secondes'}');
            }),
            const SizedBox(height: 8),
            Text('Bannière Appodeal seule (sans repli : vide = Appodeal n\'a rien servi)', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
            const AppodealBannerWidget(),
            const SizedBox(height: 8),
            Text('Bannière de l\'application (Appodeal, sinon AdMob en direct) et native', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
            const AdBanner(),
            const AdmobNativeWidget(),
            const SizedBox(height: 12),
            Text(_status, style: TextStyle(color: colors.textSecondary, fontSize: 12)),
            const SizedBox(height: 12),
            btn('Voir les erreurs renvoyées par Google', () => setState(() {})),
            const SizedBox(height: 8),
            Text(
              AdmobService.lastErrors.isEmpty
                  ? 'Aucune erreur enregistrée'
                  : AdmobService.lastErrors.entries.map((e) => '${e.key} → ${e.value}').join('\n'),
              style: TextStyle(color: colors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
