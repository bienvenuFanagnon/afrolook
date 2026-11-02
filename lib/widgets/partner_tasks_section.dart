import 'dart:async';
import 'package:afrotok/services/currency_service.dart';
import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:afrotok/services/api/api_gateway.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../ads/task_ads.dart';
import '../l10n/tr.dart';
import '../pages/offerwall/partner_offers_page.dart';
import '../pages/offerwall/partner_wall_page.dart';
import '../pages/user/inviteAmis.dart';
import '../providers/authProvider.dart';
import '../theme/app_colors.dart';

/// « Tâches de nos partenaires » : gains SÉPARÉS de tous les autres (Partage et gagne, pubs…).
/// Carte COMPACTE : trois chiffres (en attente, versées, annulées) et un résumé d'une ligne ; toutes les explications (30 jours, exemples,
/// gains du mois, parrainage) sont dans une fenêtre qui s'ouvre au toucher du « i ». Les gains sont d'abord « en attente » : nos partenaires
/// gardent les fonds 30 jours et peuvent annuler une tâche (fraude détectée ou autre raison).
/// Le nom du partenaire n'est jamais affiché (clause de confidentialité du contrat).
class PartnerTasksSection extends StatefulWidget {
  const PartnerTasksSection({super.key});

  /// Ouvre les tâches (galerie, avec une pub avant chaque offre ; ou page web selon le réglage du serveur). Les erreurs s'affichent dans une bannière.
  // Dernier résumé reçu (rempli aussi par la section de la page) : le toucher n'attend plus un aller-retour réseau quand il est récent
  static Map<String, dynamic>? _lastSummary;
  static DateTime? _lastSummaryAt;

  static Future<void> open(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    void say(String m) => messenger.showSnackBar(SnackBar(content: Text(m)));
    try {
      final fresh = _lastSummary != null && _lastSummaryAt != null && DateTime.now().difference(_lastSummaryAt!).inSeconds < 60;
      final d = fresh ? _lastSummary! : Map<String, dynamic>.from(ApiClient.data(await ApiGateway.instance.client.get('/offerwall/torox/summary')) as Map);
      if (!fresh) {
        _lastSummary = d;
        _lastSummaryAt = DateTime.now();
      }
      if (d['enabled'] != true) {
        say(tr('Les tâches ne sont pas disponibles pour le moment.'));
        return;
      }
      if (!context.mounted) return;
      // Mode « galerie » : NOTRE écran d'offres. La pub passe UNE fois, avant la liste (comme pour les missions) ; plus de pub quand on touche une tâche, pour ne pas prêter à confusion.
      if (d['mode'] == 'gallery') {
        // La page s'ouvre TOUT DE SUITE (son chargement se fait derrière) et la pub passe par-dessus : à la fermeture de la pub, la liste est déjà là.
        final user = Provider.of<UserAuthProvider>(context, listen: false).loginUserData;
        final page = Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PartnerOffersPage()));
        unawaited(TaskAds.beforeTasks(user));
        await page;
        return;
      }
      final r = Map<String, dynamic>.from(ApiClient.data(await ApiGateway.instance.client.get('/offerwall/torox/wall')) as Map);
      if (!context.mounted) return;
      // Une pub plein écran d'abord (jamais bloquante : plafond par jour, comptes sans pub exclus), puis la liste des tâches
      final user = Provider.of<UserAuthProvider>(context, listen: false).loginUserData;
      final page = Navigator.of(context).push(MaterialPageRoute(builder: (_) => PartnerWallPage(url: '${r['url']}')));
      unawaited(TaskAds.beforeTasks(user));
      await page;
    } on ApiException catch (e) {
      say(switch (e.code) {
        'account_too_young' => tr('Les tâches seront disponibles dans quelques jours.'),
        'email_unverified' => tr('Confirme ton e-mail pour utiliser cette fonction.'),
        'account_inactive' => tr('Compte non éligible.'),
        _ => tr('Les tâches ne sont pas disponibles pour le moment.'),
      });
    } catch (_) {
      say(tr('Impossible d\'ouvrir les tâches pour le moment. Réessaie plus tard.'));
    }
  }

  @override
  State<PartnerTasksSection> createState() => PartnerTasksSectionState();
}

class PartnerTasksSectionState extends State<PartnerTasksSection> {
  static final NumberFormat _n = NumberFormat.decimalPattern('fr');

  Map<String, dynamic>? _data;
  bool _loading = true;

  /// Délai avant le versement des gains de tâches (jours), tel que donné par le serveur.
  int get holdDays => (_data?['hold_days'] as num?)?.toInt() ?? 30;
  String? _error;

  @override
  void initState() {
    super.initState();
    reload();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) TaskAds.warmUp(Provider.of<UserAuthProvider>(context, listen: false).loginUserData);   // la pub plein écran se prépare avant le toucher
    });
  }

  /// Relit les gains (appelé aussi au retour de la liste des tâches).
  Future<void> reload() async {
    try {
      final r = ApiClient.data(await ApiGateway.instance.client.get('/offerwall/torox/summary'));
      if (!mounted) return;
      setState(() {
        _data = Map<String, dynamic>.from(r as Map);
        PartnerTasksSection._lastSummary = _data;
        PartnerTasksSection._lastSummaryAt = DateTime.now();
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = tr('Impossible de charger les tâches pour le moment. Réessaie plus tard.'); });
    }
  }

  String _date(dynamic iso) {
    final d = DateTime.tryParse('$iso')?.toLocal();
    return d == null ? '' : DateFormat('dd/MM/yyyy').format(d);
  }

  String _statusLabel(String s) => switch (s) {
        'held' => tr('En attente'),
        'released' => tr('Versée'),
        'reversed' => tr('Annulée'),
        _ => tr('Refusée'),
      };

  Widget _amount(AppColors c, String label, int coins, Color color) => Expanded(
        child: Column(children: [
          Text(_n.format(coins), style: TextStyle(color: color, fontSize: 19, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary, fontSize: 11.5)),
        ]),
      );

  String _coinsLine(num coins, num fcfa) => '${tr('{c} pièces (environ {f} F)', {'c': _n.format(coins.toInt()), 'f': _n.format(fcfa.toInt())})} · ≈ ${Money.usd(fcfa)}';

  Widget _monthlyCard(AppColors c, List<Map> monthly, int holdDays) {
    String label(Map m) {
      final n = (m['tasks'] as num?)?.toInt() ?? 0;
      return switch ((m['example'] as num?)?.toInt() ?? 0) {
        1 => tr('Si tu fais {n} tâche(s) moyenne(s) dans le mois', {'n': n}),
        2 => tr('Si tu fais {n} tâche(s) longue(s) dans le mois', {'n': n}),
        _ => tr('Si tu fais {n} tâche(s) légère(s) dans le mois', {'n': n}),
      };
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: c.primary.withOpacity(0.35))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr('Gagne de l\'argent à la fin du mois'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
        const SizedBox(height: 4),
        Text(tr('Reste actif : un peu chaque jour fait vite monter ton gain du mois.'), style: TextStyle(color: c.textSecondary, fontSize: 12.5, height: 1.35)),
        const SizedBox(height: 8),
        for (final m in monthly.take(3))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Text(label(m), style: TextStyle(color: c.textSecondary, fontSize: 12.5))),
              const SizedBox(width: 8),
              Text(_coinsLine((m['coins'] as num?) ?? 0, (m['fcfa'] as num?) ?? 0), style: TextStyle(color: c.primary, fontWeight: FontWeight.w800, fontSize: 12.5)),
            ]),
          ),
        const SizedBox(height: 4),
        Text(tr('Exemples non garantis : ce sont surtout des jeux où il faut atteindre un niveau, en plusieurs jours. Les gains sont versés après {n} jours.', {'n': holdDays}), style: TextStyle(color: c.textSecondary.withOpacity(0.85), fontSize: 11.5, height: 1.3)),
      ]),
    );
  }

  Widget _sponsorCard(AppColors c, Map<String, dynamic> d, Map<String, dynamic> sp, int friends) {
    final pct = (d['sponsor_pct'] as num?)?.toInt() ?? 10;
    final earned = (d['sponsor_earned_coins'] as num?)?.toInt() ?? 0;
    final pending = (d['sponsor_pending_coins'] as num?)?.toInt() ?? 0;
    final tasks = (sp['tasks_per_friend'] as num?)?.toInt() ?? 10;
    final scenarios = (sp['scenarios'] as List? ?? const []).whereType<Map>().toList();
    final mine = sp['mine'] is Map ? Map<String, dynamic>.from(sp['mine'] as Map) : null;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.group_add_rounded, color: c.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(tr('Invite tes amis : tu gagnes {p} % de la valeur de leurs tâches.', {'p': pct}), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 14))),
        ]),
        const SizedBox(height: 4),
        Text(tr('C\'est en plus de leurs gains : tes amis ne perdent rien.'), style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
        const SizedBox(height: 8),
        Text(tr('Amis invités : {n}', {'n': friends}), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
        if (earned > 0 || pending > 0)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(tr('Tes gains de parrain : {a} pièces versées, {p} en attente', {'a': _n.format(earned), 'p': _n.format(pending)}), style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
          ),
        if (mine != null) ...[
          const SizedBox(height: 6),
          Text(tr('Avec tes {n} amis, s\'ils font chacun {t} tâche(s) légère(s) par mois : {x}', {'n': friends, 't': tasks, 'x': _coinsLine((mine['coins'] as num?) ?? 0, (mine['fcfa'] as num?) ?? 0)}),
              style: TextStyle(color: c.primary, fontWeight: FontWeight.w800, fontSize: 12.5, height: 1.35)),
        ],
        const SizedBox(height: 6),
        Text(tr('Estimation par mois si tes amis font chacun {t} tâche(s) légère(s) :', {'t': tasks}), style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
        for (final s in scenarios.take(3))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(children: [
              Expanded(child: Text(tr('{n} amis actifs', {'n': (s['friends'] as num?)?.toInt() ?? 0}), style: TextStyle(color: c.textSecondary, fontSize: 12.5))),
              Text(_coinsLine((s['coins'] as num?) ?? 0, (s['fcfa'] as num?) ?? 0), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 12.5)),
            ]),
          ),
      ]),
    );
  }

  /// Toutes les explications, à la demande : paiement après 30 jours, exemples, gains du mois, parrainage.
  Future<void> _showInfo() async {
    final c = AppColors.of(context);
    final d = _data ?? const <String, dynamic>{};
    final holdDays = (d['hold_days'] as num?)?.toInt() ?? 30;
    final examples = (d['examples'] as List? ?? const []).whereType<Map>().toList();
    final monthly = (d['monthly'] as List? ?? const []).whereType<Map>().toList();
    final sp = d['sponsor_estimates'] is Map ? Map<String, dynamic>.from(d['sponsor_estimates'] as Map) : <String, dynamic>{};
    final friends = (d['friends_count'] as num?)?.toInt() ?? 0;
    final pending = (d['pending_coins'] as num?)?.toInt() ?? 0;
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
            Text(tr('Comment ça marche ?'), style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(tr('Jeux, sondages, applications : ces gains sont séparés de tes autres gains (Partage et gagne, publicités…).'), style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.4)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: c.info.withOpacity(0.10), borderRadius: BorderRadius.circular(10)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.hourglass_bottom_rounded, size: 18, color: c.info),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr('Le paiement de ces tâches arrive après {n} jours : nos partenaires gardent les fonds pendant {n} jours et peuvent annuler une tâche en cas de fraude détectée ou pour une autre raison. Tes pièces te sont versées une fois la tâche confirmée.', {'n': holdDays}),
                    style: TextStyle(color: c.textPrimary, fontSize: 12.5, height: 1.4),
                  ),
                ),
              ]),
            ),
            if (pending > 0 && d['next_release_at'] != null) ...[
              const SizedBox(height: 8),
              Text(tr('Prochain versement possible : {d}', {'d': _date(d['next_release_at'])}), style: TextStyle(color: c.textSecondary, fontSize: 12)),
            ],
            if (d['waiting_for_payment'] == true) ...[
              const SizedBox(height: 6),
              Text(tr('Les premiers versements commencent quand nos partenaires nous ont payés : cela peut prendre plus de {n} jours.', {'n': holdDays}), style: TextStyle(color: c.textSecondary, fontSize: 12, height: 1.35)),
            ],
            // Exemples de gains pour UNE tâche (calculés par le serveur ; chaque tâche affiche ses pièces exactes)
            if (examples.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(tr('Ce que tu peux gagner sur une seule tâche'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 6),
              for (var k = 0; k < examples.length && k < 3; k++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Icon(Icons.monetization_on_outlined, size: 18, color: c.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text([tr('Tâche légère'), tr('Tâche moyenne'), tr('Tâche longue')][k], style: TextStyle(color: c.textSecondary, fontSize: 13))),
                    Text('${tr('{c} pièces (environ {f} F)', {'c': _n.format((examples[k]['coins'] as num?)?.toInt() ?? 0), 'f': _n.format((examples[k]['fcfa'] as num?)?.toInt() ?? 0)})} · ≈ ${Money.usd((examples[k]['fcfa'] as num?) ?? 0)}',
                        style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                  ]),
                ),
              const SizedBox(height: 2),
              Text(tr('Exemples indicatifs : chaque tâche affiche ses pièces exactes. Ce sont surtout des jeux à jouer plusieurs jours pour atteindre un niveau.'), style: TextStyle(color: c.textSecondary.withOpacity(0.85), fontSize: 11.5, height: 1.3)),
            ],
            if (monthly.isNotEmpty) ...[const SizedBox(height: 14), _monthlyCard(c, monthly, holdDays)],
            if (sp.isNotEmpty) ...[const SizedBox(height: 14), _sponsorCard(c, d, sp, friends)],
            const SizedBox(height: 10),
            Text(tr('Une publicité s\'ouvre avant chaque tâche.'), style: TextStyle(color: c.textSecondary.withOpacity(0.8), fontSize: 11.5)),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final d = _data;
    final pending = (d?['pending_coins'] as num?)?.toInt() ?? 0;
    final released = (d?['released_coins'] as num?)?.toInt() ?? 0;
    final reversed = (d?['reversed_coins'] as num?)?.toInt() ?? 0;
    final holdDays = (d?['hold_days'] as num?)?.toInt() ?? 30;
    final recent = (d?['recent'] as List? ?? const []).whereType<Map>().toList();
    final friends = (d?['friends_count'] as num?)?.toInt() ?? 0;
    final sponsorPct = (d?['sponsor_pct'] as num?)?.toInt() ?? 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 12),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(tr('Mes gains de tâches'), style: TextStyle(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w800))),
            IconButton(
              tooltip: tr('Comment ça marche ?'),
              visualDensity: VisualDensity.compact,
              onPressed: _loading ? null : _showInfo,
              icon: Icon(Icons.info_outline_rounded, color: c.textSecondary),
            ),
          ]),
          if (_loading)
            Center(child: Padding(padding: const EdgeInsets.all(8), child: CircularProgressIndicator(color: c.primary, strokeWidth: 2)))
          else ...[
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(children: [
                _amount(c, tr('En attente'), pending, c.info),
                _amount(c, tr('Versées'), released, c.primary),
                _amount(c, tr('Annulées'), reversed, c.textSecondary),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 10, right: 8),
              child: Row(children: [
                Icon(Icons.hourglass_bottom_rounded, size: 15, color: c.textSecondary),
                const SizedBox(width: 6),
                Expanded(child: Text(tr('Versés après {n} jours', {'n': holdDays}), style: TextStyle(color: c.textSecondary, fontSize: 12))),
              ]),
            ),
          ],
          if (_error != null)
            Padding(padding: const EdgeInsets.only(top: 8, right: 8), child: Text(_error!, style: TextStyle(color: c.warning, fontWeight: FontWeight.w700, fontSize: 13))),
        ]),
      ),
      if (sponsorPct > 0) ...[
        const SizedBox(height: 10),
        Material(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => showInviteFriendsModal(context, Provider.of<UserAuthProvider>(context, listen: false).loginUserData),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border)),
              child: Row(children: [
                Icon(Icons.group_add_rounded, color: c.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tr('Inviter mes amis'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 14.5)),
                    Text(friends > 0 ? tr('Amis invités : {n}', {'n': friends}) : tr('Tu gagnes {p} % de leurs tâches', {'p': sponsorPct}), style: TextStyle(color: c.textSecondary, fontSize: 12)),
                  ]),
                ),
                Icon(Icons.chevron_right_rounded, color: c.textSecondary),
              ]),
            ),
          ),
        ),
      ],
      if (recent.isNotEmpty) ...[
        const SizedBox(height: 6),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 4),
            title: Text(tr('Tes tâches récentes'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
            children: [
              for (final t in recent.take(8))
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(children: [
                    Expanded(child: Text('${t['offer'] ?? tr('Tâche')}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textPrimary, fontSize: 13))),
                    const SizedBox(width: 8),
                    Text('${_n.format((t['coins'] as num?)?.toInt() ?? 0)} · ${_statusLabel('${t['status']}')}', style: TextStyle(color: t['status'] == 'released' ? c.primary : c.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ]),
                ),
            ],
          ),
        ),
      ],
    ]);
  }
}
