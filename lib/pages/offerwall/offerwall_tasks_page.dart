import 'package:afrotok/services/currency_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

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
import '../../widgets/partner_tasks_section.dart';
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
  bool _openingTasks = false;
  bool _ageOk = false;
  bool _ageChecked = false;
  // « Comment ça marche ? » : toujours replié au départ (la personne l'ouvre au toucher)
  bool _howOpen = false;
  final GlobalKey<PartnerTasksSectionState> _partnerKey = GlobalKey<PartnerTasksSectionState>();
  OfferwallInfo? _info;
  String? _error;

  UserAuthProvider get _auth => Provider.of<UserAuthProvider>(context, listen: false);
  String get _uid => _auth.loginUserData.id ?? '';

  @override
  void initState() {
    super.initState();
    _load();
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        CenteredContent(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Les deux entrées en haut, simples : missions de partage ET tâches des partenaires
            _topActions(c),
            const SizedBox(height: 12),
            _howCard(c),
            const SizedBox(height: 12),
            OfferwallEarningsCard(userId: _uid),
            const SizedBox(height: 12),
            // Gains des tâches de nos partenaires (séparés des autres, payés après 30 jours) : carte compacte, explications au toucher du « i »
            PartnerTasksSection(key: _partnerKey),
            if (partners) ...[
              const SizedBox(height: 12),
              _legacyTasks(c, info, usable),
            ],
            _ad(AdSlotKind.detail),
            _ad(AdSlotKind.list),
            const SizedBox(height: 6),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                childrenPadding: EdgeInsets.zero,
                title: Text(context.tr('Mon historique'), style: TextStyle(color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
                children: [
                  if (info.events.isEmpty)
                    Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text(context.tr('Aucune tâche pour le moment.'), style: TextStyle(color: c.textSecondary)))
                  else
                    for (final e in info.events) _historyRow(c, e),
                ],
              ),
            ),
          ]),
        ),
      ],
    );
  }


  /// « Comment ça marche ? » : trois lignes toujours visibles, tout le détail au toucher de « Lire plus ».
  Widget _howCard(AppColors c) {
    Widget step(String n, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(radius: 9, backgroundColor: c.primary.withOpacity(0.15), child: Text(n, style: TextStyle(color: c.primary, fontSize: 10.5, fontWeight: FontWeight.w800))),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: TextStyle(color: c.textPrimary, fontSize: 12.5, height: 1.3))),
          ]),
        );
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(context.tr('Comment ça marche ?'), style: TextStyle(color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        step('1', context.tr('Choisis une mission ou une tâche.')),
        step('2', context.tr('Fais-la en suivant les consignes.')),
        step('3', context.tr('Tes pièces arrivent « en attente », puis sont versées : tu les convertis en argent.')),
        Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => _showHow(c), child: Text(context.tr('Lire plus')))),
      ]),
    );
  }

  Future<void> _showHow(AppColors c) async {
    final holdDays = _partnerKey.currentState?.holdDays ?? 30;
    Widget block(IconData icon, String title, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: c.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
                const SizedBox(height: 2),
                Text(text, style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.4)),
              ]),
            ),
          ]),
        );
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.background,
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.tr('Comment ça marche ?'), style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            block(Icons.campaign_rounded, context.tr('Les missions (Partage et gagne)'),
                context.tr("Tu partages des annonces sur WhatsApp, Telegram, Facebook ou TikTok avec ton lien personnel. Chaque clic valide te rapporte des pièces. Elles restent « en attente » {h} h, puis elles sont ajoutées à ton solde.", {'h': _shareHome.holdHours})),
            block(Icons.task_alt_rounded, context.tr('Les tâches de nos partenaires'),
                context.tr("Jeux, sondages et applications : tu choisis une tâche, tu la fais en suivant ses consignes (traduites dans ta langue quand c'est possible). Tes pièces sont « en attente » {n} jours : nos partenaires vérifient ton travail et peuvent annuler une tâche en cas de fraude.", {'n': holdDays})),
            block(Icons.savings_rounded, context.tr('Convertir en argent'),
                context.tr("Quand tes pièces sont versées, elles rejoignent tes pièces gagnées. Tu peux les convertir en argent réel : 25 pièces valent 10 F.")),
            block(Icons.group_add_rounded, context.tr('Invite tes amis'),
                context.tr("Tu gagnes en plus un pourcentage de ce que gagnent tes amis, sans rien leur retirer.")),
            block(Icons.rule_rounded, context.tr('À respecter'),
                context.tr("Fais chaque tâche toi-même et une seule fois. Une tâche non conforme peut être refusée, et un gain peut être retiré en cas de fraude.")),
          ]),
        ),
      ),
    );
  }

  /// Les deux entrées, côte à côte et en haut de la page : « Voir les missions » (Partage et gagne) et « Voir les tâches » (partenaires).
  Widget _topActions(AppColors c) {
    Widget tile(IconData icon, String title, String subtitle, VoidCallback? onTap, {bool busy = false}) => Expanded(
          child: Material(
            color: c.surface,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: c.primary.withOpacity(0.45))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: c.primary.withOpacity(0.14), borderRadius: BorderRadius.circular(12)),
                    child: busy ? Padding(padding: const EdgeInsets.all(11), child: CircularProgressIndicator(strokeWidth: 2, color: c.primary)) : Icon(icon, color: c.primary),
                  ),
                  const SizedBox(height: 10),
                  Text(title, style: TextStyle(color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textSecondary, fontSize: 12, height: 1.3)),
                ]),
              ),
            ),
          ),
        );
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        tile(Icons.campaign_rounded, context.tr('Voir les missions'), '${context.tr('Partage et gagne : {f} F par clic valide', {'f': _n.format(_shareHome.perClickFcfa)})} (≈ ${Money.usd(_shareHome.perClickFcfa)})', _opening ? null : _openShare, busy: _opening),
        const SizedBox(width: 12),
        tile(Icons.task_alt_rounded, context.tr('Voir les tâches'), context.tr('Jeux, sondages et applications'), _openingTasks ? null : () async {
          setState(() => _openingTasks = true);   // retour visuel immédiat : la liste peut mettre un instant à s'ouvrir
          try {
            await PartnerTasksSection.open(context);
          } finally {
            if (mounted) setState(() => _openingTasks = false);
          }
          _partnerKey.currentState?.reload();
        }, busy: _openingTasks),
      ]),
    );
  }

  /// Anciennes plateformes de tâches (seulement quand elles sont actives) : un bouton et une explication repliée.
  Widget _legacyTasks(AppColors c, OfferwallInfo info, bool usable) {
    return _card(c, [
      Text(context.tr('Autres tâches'), style: TextStyle(color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      const OfferwallPromoBanner(),
      const SizedBox(height: 10),
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
            label: Text(context.tr('Ouvrir la liste')),
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
      const SizedBox(height: 4),
      InkWell(
        onTap: () => setState(() => _howOpen = !_howOpen),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Expanded(child: Text(context.tr('Comment ça marche ?'), style: TextStyle(color: c.textSecondary, fontSize: 13, fontWeight: FontWeight.w700))),
            Icon(_howOpen ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: c.textSecondary),
          ]),
        ),
      ),
      if (_howOpen) ...[
        _step(c, '1', context.tr('Choisis une tâche dans la liste de nos partenaires.')),
        _step(c, '2', context.tr('Fais-la en suivant ses consignes : c\'est ton travail du jour.')),
        _step(c, '3', context.tr('Ta paie apparaît tout de suite en pièces « en attente ».')),
        _step(c, '4', context.tr('Après {h} h, elles deviennent des Pièces gagnées que tu convertis en argent réel.', {'h': info.holdHours})),
        const SizedBox(height: 6),
        Text(context.tr('Une tâche peut être refusée si ses consignes ne sont pas respectées. Au-delà de {n} pièces par jour, les tâches sont examinées par notre équipe.', {'n': _n.format(info.dailyCapCoins)}), style: TextStyle(color: c.textSecondary, fontSize: 12, height: 1.35)),
      ],
    ]);
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
