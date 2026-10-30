import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../ads/ad_config.dart';
import '../../ads/ad_gate.dart';
import '../../ads/ad_slot.dart';
import '../../ads/task_ads.dart';
import '../../layout/centered_content.dart';
import '../../l10n/tr.dart';
import '../../providers/authProvider.dart';
import '../../services/offerwall/offerwall_service.dart';
import '../share/share_earn_page.dart';
import '../../services/share/share_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/offerwall_dialogs.dart';
import '../../widgets/offerwall_earnings_card.dart';
import '../../widgets/offerwall_promo_banner.dart';
import '../user/inviteAmis.dart';
import 'offerwall_tutorial_page.dart';

/// Page « Gagne des pièces » : introduction dans la langue de la personne, accès au mur de tâches (Tapjoy), total gagné,
/// explications sur le déroulement (attente de 48 h), parrainage et historique. Voir docs/OFFERWALL_TACHES.md §4 et §15.
/// Tout le texte de cette page est à nous (traduit dans les 8 langues) ; seules les offres viennent des régies et sont souvent en anglais.
class OfferwallTasksPage extends StatefulWidget {
  const OfferwallTasksPage({super.key});

  @override
  State<OfferwallTasksPage> createState() => _OfferwallTasksPageState();
}

class _OfferwallTasksPageState extends State<OfferwallTasksPage> {
  static final NumberFormat _n = NumberFormat.decimalPattern('fr');

  bool _loading = true;
  ShareHome _shareHome = ShareHome.preview(); // gains affichés sur la carte « Partage et gagne » (aperçu tant que le serveur n'a pas répondu)
  bool _opening = false;
  bool _ageOk = false;
  bool _ageChecked = false;
  // « Comment ça marche ? » : ouvert seulement à la toute première visite, puis replié avec un court résumé (la personne peut l'ouvrir et le fermer)
  bool _howOpen = false;
  OfferwallInfo? _info;
  String? _error;

  UserAuthProvider get _auth => Provider.of<UserAuthProvider>(context, listen: false);
  String get _uid => _auth.loginUserData.id ?? '';

  @override
  void initState() {
    super.initState();
    _load();
    _initHow();
    // la pub plein écran se prépare tout de suite : elle sera prête quand la personne touchera « Voir les tâches »
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && OfferwallService.isConfigured) TaskAds.warmUp(_auth.loginUserData); // pub plein écran : seulement pour les plateformes de tâches
    });
    // première arrivée sur la page : le tutoriel animé (avec sons) s'ouvre tout seul, une seule fois ; ensuite, bouton du coin
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // le tutoriel annonce les gains des plateformes de tâches : il reste caché tant qu'elles sont en pause
      if (!OfferwallService.isConfigured || await OfferwallTutorialPage.alreadySeen() || !mounted) return;
      await OfferwallTutorialPage.open(context);
    });
  }

  Future<void> _load({bool force = false}) async {
    setState(() { _loading = true; _error = null; });
    try {
      final age = await OfferwallService.ageConfirmed();
      final info = await OfferwallService.loadInfo(force: force);
      if (!mounted) return;
      setState(() { _info = info; _ageOk = age; _loading = false; });
      ShareService.homeOrPreview().then((h) { if (mounted) setState(() => _shareHome = h); });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = context.tr('Impossible de charger les tâches pour le moment. Réessaie plus tard.'); _loading = false; });
    }
  }

  Future<void> _initHow() async {
    try {
      final sp = await SharedPreferences.getInstance();
      if (sp.getBool('offerwall_how_seen_v1') ?? false) return;
      await sp.setBool('offerwall_how_seen_v1', true);
      if (mounted) setState(() => _howOpen = true);
    } catch (_) {}
  }

  Future<void> _open({bool ayet = false}) async {
    if (!_ageOk) {
      if (!_ageChecked) return;
      await OfferwallService.confirmAge();
      _ageOk = true;
    }
    setState(() => _opening = true);
    // la vérification des tâches (Tapjoy) démarre tout de suite, EN MÊME TEMPS que la pub plein écran (si elle passe) : à sa fermeture, la bonne page s'ouvre
    final prefetch = ayet ? null : OfferwallService.prefetchTapjoy(_uid);
    await TaskAds.beforeTasks(_auth.loginUserData);
    if (!mounted) return;
    final r = ayet ? await OfferwallService.openAyet(_uid) : await OfferwallService.open(_uid, prefetched: prefetch);
    if (!mounted) return;
    setState(() => _opening = false);
    if (r == OfferwallOpenResult.unavailable) {
      await showOfferwallNoTasksDialog(context);
    } else if (r == OfferwallOpenResult.error) {
      await showOfferwallErrorDialog(context);
    }
  }

  String _statusLabel(String s) => switch (s) {
        'pending' => context.tr('En attente'),
        'validee' => context.tr('Validée'),
        'en_revue' => context.tr('En cours d\'examen'),
        'refusee' || 'refusee_admin' => context.tr('Refusée'),
        'expiree' => context.tr('Expirée'),
        'annulee' => context.tr('Annulée'),
        _ => s,
      };

  Color _statusColor(String s, AppColors c) => switch (s) {
        'validee' => c.primary,
        'pending' => c.info,
        'en_revue' => c.warning,
        _ => c.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(backgroundColor: c.surface, foregroundColor: c.textPrimary, title: Text(context.tr('Travaille et gagne de l\'argent')),
        actions: [
          if (OfferwallService.isConfigured)
            IconButton(
              tooltip: context.tr('Voir le tutoriel'),
              icon: const Icon(Icons.play_circle_fill_rounded),
              onPressed: () => OfferwallTutorialPage.open(context),
            ),
        ],
      ),
      // mention discrète : une pub plein écran peut s'ouvrir pendant la vérification des tâches (seulement pour les comptes qui voient des pubs)
      bottomNavigationBar: (_loading || _error != null || !OfferwallService.isConfigured || !AdConfig.current.tasksInterstitial || !AdGate.canShowType(_auth.loginUserData, 'interstitial'))
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
                child: Text(
                  context.tr('Une publicité peut s\'ouvrir pendant la vérification de la disponibilité des tâches.'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.textSecondary.withOpacity(0.8), fontSize: 11, height: 1.3),
                ),
              ),
            ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: c.primary))
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary))))
              : RefreshIndicator(color: c.primary, onRefresh: () => _load(force: true), child: _content(c)),
    );
  }

  Widget _content(AppColors c) {
    final info = _info!;
    final partners = OfferwallService.isConfigured; // plateformes de tâches actives (en pause : seule la tâche « Regarder une pub » est proposée)
    final usable = partners && info.availableHere && !info.blocked;
    final user = _auth.loginUserData;
    final sponsorPct = (info.sponsorPct / 2).round(); // 20 % des pièces de l'utilisateur = 10 % de la valeur de la tâche
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        CenteredContent(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            OfferwallEarningsCard(userId: _uid),
            const SizedBox(height: 12),
            _shareCard(c),
            if (partners) ...[
            const SizedBox(height: 12),
            _card(c, [
              Text(context.tr('Travaille dans Afrolook, sois payé'), style: TextStyle(color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(context.tr('Chaque tâche terminée est un travail payé : jeux, sondages, applications de nos partenaires. Tu gagnes des pièces que tu convertis en argent réel.'), style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.4)),
              const SizedBox(height: 12),
              const OfferwallPromoBanner(),
              const SizedBox(height: 14),
              if (!usable)
                Text(
                  info.blocked ? context.tr('Les tâches sont suspendues pour ton compte.') : context.tr('Les tâches ne sont pas disponibles pour le moment.'),
                  style: TextStyle(color: c.warning, fontWeight: FontWeight.w700),
                )
              else ...[
                if (!_ageOk)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _ageChecked,
                    onChanged: (v) => setState(() => _ageChecked = v ?? false),
                    title: Text(context.tr('J\'ai 18 ans ou plus'), style: TextStyle(color: c.textPrimary, fontSize: 13.5)),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: (_opening || (!_ageOk && !_ageChecked)) ? null : _open,
                    icon: _opening ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.task_alt_rounded),
                    label: Text(context.tr('Voir les tâches')),
                  ),
                ),
                // seconde source de tâches (ayeT) : quand Tapjoy est vide, l'ouverture normale bascule déjà ; ce bouton permet d'en voir plus
                if (OfferwallService.tapjoyConfigured && OfferwallService.ayetConfigured)
                  Align(
                    alignment: Alignment.center,
                    child: TextButton(
                      onPressed: (_opening || (!_ageOk && !_ageChecked)) ? null : () => _open(ayet: true),
                      child: Text(context.tr('Voir plus de tâches')),
                    ),
                  ),
              ],
            ]),
            const SizedBox(height: 12),
            _card(c, [
              InkWell(
                onTap: () => setState(() => _howOpen = !_howOpen),
                child: Row(children: [
                  Expanded(child: Text(context.tr('Comment ça marche ?'), style: TextStyle(color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.w800))),
                  Icon(_howOpen ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: c.textSecondary),
                ]),
              ),
              const SizedBox(height: 8),
              if (_howOpen) ...[
              _step(c, '1', context.tr('Choisis une tâche dans la liste de nos partenaires.')),
              _step(c, '2', context.tr('Fais-la en suivant ses consignes : c\'est ton travail du jour.')),
              _step(c, '3', context.tr('Ta paie apparaît tout de suite en pièces « en attente ».')),
              _step(c, '4', context.tr('Après {h} h, elles deviennent des Pièces gagnées que tu convertis en argent réel.', {'h': info.holdHours})),
              const SizedBox(height: 8),
              Text(context.tr('Les offres viennent de nos partenaires : certaines sont en anglais.'), style: TextStyle(color: c.textSecondary, fontSize: 12, height: 1.35)),
              const SizedBox(height: 4),
              Text(context.tr('Une tâche peut être refusée si ses consignes ne sont pas respectées. Au-delà de {n} pièces par jour, les tâches sont examinées par notre équipe.', {'n': _n.format(info.dailyCapCoins)}), style: TextStyle(color: c.textSecondary, fontSize: 12, height: 1.35)),
              ] else
                Text(context.tr('Choisis une tâche, fais-la, puis reçois ta paie en pièces : convertie en argent réel après {h} h.', {'h': info.holdHours}), style: TextStyle(color: c.textSecondary, fontSize: 12.5, height: 1.4)),
            ]),
            ],
            _ad(AdSlotKind.detail),
            if (partners && sponsorPct > 0) ...[
              const SizedBox(height: 12),
              _card(c, [
                Row(children: [
                  Icon(Icons.group_add_rounded, color: c.primary),
                  const SizedBox(width: 10),
                  Expanded(child: Text(context.tr('Invite tes amis : tu gagnes {p} % de la valeur de leurs tâches.', {'p': sponsorPct}), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 13.5))),
                ]),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton(onPressed: () => showInviteFriendsModal(context, user), child: Text(context.tr('Inviter mes amis'))),
                ),
              ]),
            ],
            _ad(AdSlotKind.list),
            const SizedBox(height: 10),
            Text(context.tr('Mon historique'), style: TextStyle(color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            if (info.events.isEmpty)
              Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text(context.tr('Aucune tâche pour le moment.'), style: TextStyle(color: c.textSecondary)))
            else
              for (final e in info.events) _historyRow(c, e),
          ]),
        ),
      ],
    );
  }

  /// Emplacement publicitaire (bannière ou native) : vide pour les comptes sans pub ; jamais collé au bouton des tâches.
  Widget _ad(AdSlotKind kind) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        // réseaux publicitaires seulement (AdMob / Appodeal) : jamais de pub Afrolook sur cette page
        child: AdSlot(kind: kind, own: () => const SizedBox.shrink(), admobFirst: true, allowOwn: false),
      );

  Widget _card(AppColors c, List<Widget> children) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  Widget _step(AppColors c, String n, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(radius: 10, backgroundColor: c.primary.withOpacity(0.15), child: Text(n, style: TextStyle(color: c.primary, fontSize: 11, fontWeight: FontWeight.w800))),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: c.textPrimary, fontSize: 13, height: 1.35))),
        ]),
      );

  /// Portail : une pub plein écran passe d'abord (comptes qui voient des pubs), puis la page des missions s'ouvre. Ne bloque jamais l'accès.
  Future<void> _openShare() async {
    if (_opening) return;
    setState(() => _opening = true);
    await TaskAds.beforeTasks(_auth.loginUserData);
    if (!mounted) return;
    setState(() => _opening = false);
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ShareEarnPage()));
  }

  /// Entrée vers « Partage et gagne » : partager des annonces (WhatsApp, Telegram, Facebook…) et être payé au clic valide.
  Widget _shareCard(AppColors c) => _card(c, [
        Row(children: [
          Icon(Icons.campaign_rounded, color: c.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(context.tr('Partage et gagne'), style: TextStyle(color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.w800))),
        ]),
        const SizedBox(height: 6),
        Text(context.tr('Partage des annonces sur WhatsApp, Telegram, Facebook… et gagne de l\'argent : environ {f} F par clic valide, jusqu\'à {m} F par jour.', {'f': _n.format(_shareHome.perClickFcfa), 'm': _n.format(_shareHome.dailyCapFcfa)}), style: TextStyle(color: c.textSecondary, fontSize: 13.5, height: 1.35)),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _opening ? null : _openShare, icon: const Icon(Icons.arrow_forward_rounded), label: Text(context.tr('Voir les missions')))),
      ]);

  /// D'où vient le gain : partage (avec la plateforme) ou tâche d'un partenaire.
  String _sourceLabel(OfferwallEntry e) {
    if (e.provider == 'whatsapp_partage') {
      final p = switch (e.platform) { 'whatsapp' => 'WhatsApp', 'telegram' => 'Telegram', 'facebook' => 'Facebook', 'tiktok' => 'TikTok', _ => context.tr('Autre réseau') };
      return context.tr('Partage {p}', {'p': p});
    }
    return context.tr('Tâche d\'un partenaire');
  }

  Widget _historyRow(AppColors c, OfferwallEntry e) {
    final color = _statusColor(e.status, c);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border)),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('+${_n.format(e.coins)} ${context.tr('pièces')}', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
            Text(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.fromMillisecondsSinceEpoch(e.createdAt)), style: TextStyle(color: c.textSecondary, fontSize: 11.5)),
            Text(_sourceLabel(e), style: TextStyle(color: c.primary, fontSize: 11.5, fontWeight: FontWeight.w700)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(999)),
          child: Text(_statusLabel(e.status), style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }
}
