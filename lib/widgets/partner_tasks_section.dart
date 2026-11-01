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

/// « Tâches de nos partenaires » : gains SÉPARÉS de tous les autres (Partage et gagne, pubs…), avec l'explication des 30 jours.
/// Les gains sont d'abord « en attente » : nos partenaires gardent les fonds 30 jours et peuvent annuler une tâche (fraude détectée ou autre raison).
/// Le nom du partenaire n'est jamais affiché (clause de confidentialité du contrat).
class PartnerTasksSection extends StatefulWidget {
  const PartnerTasksSection({super.key});

  @override
  State<PartnerTasksSection> createState() => _PartnerTasksSectionState();
}

class _PartnerTasksSectionState extends State<PartnerTasksSection> {
  static final NumberFormat _n = NumberFormat.decimalPattern('fr');

  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _opening = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) TaskAds.warmUp(Provider.of<UserAuthProvider>(context, listen: false).loginUserData);   // la pub plein écran se prépare avant le toucher
    });
  }

  Future<void> _load() async {
    try {
      final r = ApiClient.data(await ApiGateway.instance.client.get('/offerwall/torox/summary'));
      if (!mounted) return;
      setState(() {
        _data = Map<String, dynamic>.from(r as Map);
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = tr('Impossible de charger les tâches pour le moment. Réessaie plus tard.'); });
    }
  }

  Future<void> _open() async {
    if (_opening) return;
    setState(() { _opening = true; _error = null; });
    try {
      // Mode « galerie » : NOTRE écran d'offres (la pub s'ouvre avant chaque offre, pas avant la liste)
      if (_data?['mode'] == 'gallery') {
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PartnerOffersPage()));
        if (mounted) _load();
        return;
      }
      final r = Map<String, dynamic>.from(ApiClient.data(await ApiGateway.instance.client.get('/offerwall/torox/wall')) as Map);
      if (!mounted) return;
      // Une pub plein écran d'abord (jamais bloquante : plafond par jour, comptes sans pub exclus), puis la liste des tâches
      await TaskAds.beforeTasks(Provider.of<UserAuthProvider>(context, listen: false).loginUserData);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => PartnerWallPage(url: '${r['url']}')));
      if (mounted) _load();   // les gains arrivent par le serveur : on relit en revenant
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = switch (e.code) {
              'account_too_young' => tr('Les tâches seront disponibles dans quelques jours.'),
              'email_unverified' => tr('Confirme ton e-mail pour utiliser cette fonction.'),
              'account_inactive' => tr('Compte non éligible.'),
              _ => tr('Les tâches ne sont pas disponibles pour le moment.'),
            });
      }
    } catch (_) {
      if (mounted) setState(() => _error = tr('Impossible d\'ouvrir les tâches pour le moment. Réessaie plus tard.'));
    } finally {
      if (mounted) setState(() => _opening = false);
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
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border)),
          child: Column(children: [
            Text(_n.format(coins), style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label, textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary, fontSize: 11.5)),
          ]),
        ),
      );

  String _coinsLine(num coins, num fcfa) => tr('{c} pièces (environ {f} F)', {'c': _n.format(coins.toInt()), 'f': _n.format(fcfa.toInt())});

  Widget _monthlyCard(AppColors c, List<Map> monthly, int holdDays) {
    String label(Map m) {
      final n = (m['tasks'] as num?)?.toInt() ?? 0;
      return switch ((m['example'] as num?)?.toInt() ?? 0) {
        1 => tr('Si tu fais {n} tâches moyennes dans le mois', {'n': n}),
        2 => tr('Si tu fais {n} tâches longues dans le mois', {'n': n}),
        _ => tr('Si tu fais {n} tâches courtes dans le mois', {'n': n}),
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
        Text(tr('Exemples non garantis : les offres dépendent de ton pays. Les gains sont versés après {n} jours.', {'n': holdDays}), style: TextStyle(color: c.textSecondary.withOpacity(0.85), fontSize: 11.5, height: 1.3)),
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
          Text(tr('Avec tes {n} amis, s\'ils font chacun {t} tâches courtes par mois : {x}', {'n': friends, 't': tasks, 'x': _coinsLine((mine['coins'] as num?) ?? 0, (mine['fcfa'] as num?) ?? 0)}),
              style: TextStyle(color: c.primary, fontWeight: FontWeight.w800, fontSize: 12.5, height: 1.35)),
        ],
        const SizedBox(height: 6),
        Text(tr('Estimation par mois si tes amis font chacun {t} tâches courtes :', {'t': tasks}), style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
        for (final s in scenarios.take(3))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(children: [
              Expanded(child: Text(tr('{n} amis actifs', {'n': (s['friends'] as num?)?.toInt() ?? 0}), style: TextStyle(color: c.textSecondary, fontSize: 12.5))),
              Text(_coinsLine((s['coins'] as num?) ?? 0, (s['fcfa'] as num?) ?? 0), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 12.5)),
            ]),
          ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton(
            onPressed: () => showInviteFriendsModal(context, Provider.of<UserAuthProvider>(context, listen: false).loginUserData),
            child: Text(tr('Inviter mes amis')),
          ),
        ),
      ]),
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
    final enabled = d?['enabled'] == true;
    final examples = (d?['examples'] as List? ?? const []).whereType<Map>().toList();
    final monthly = (d?['monthly'] as List? ?? const []).whereType<Map>().toList();
    final sp = d?['sponsor_estimates'] is Map ? Map<String, dynamic>.from(d!['sponsor_estimates'] as Map) : <String, dynamic>{};
    final friends = (d?['friends_count'] as num?)?.toInt() ?? 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr('Tâches de nos partenaires'), style: TextStyle(color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(tr('Jeux, sondages, applications : ces gains sont séparés de tes autres gains (Partage et gagne, publicités…).'), style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.4)),
        const SizedBox(height: 10),
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
        // Exemples de gains pour UNE tâche (calculés par le serveur ; chaque tâche affiche ses pièces exactes)
        if (examples.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(tr('Ce que tu peux gagner sur une seule tâche'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 6),
          for (var k = 0; k < examples.length && k < 3; k++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Icon(Icons.monetization_on_outlined, size: 18, color: c.primary),
                const SizedBox(width: 8),
                Expanded(child: Text([tr('Tâche courte'), tr('Tâche moyenne'), tr('Tâche longue')][k], style: TextStyle(color: c.textSecondary, fontSize: 13))),
                Text(tr('{c} pièces (environ {f} F)', {'c': _n.format((examples[k]['coins'] as num?)?.toInt() ?? 0), 'f': _n.format((examples[k]['fcfa'] as num?)?.toInt() ?? 0)}),
                    style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
              ]),
            ),
          const SizedBox(height: 2),
          Text(tr('Exemples indicatifs : chaque tâche affiche ses pièces exactes, et les gains dépendent de la tâche.'), style: TextStyle(color: c.textSecondary.withOpacity(0.85), fontSize: 11.5, height: 1.3)),
        ],
        // « À la fin du mois » : donner envie de rester actif (exemples du serveur, jamais une promesse)
        if (monthly.isNotEmpty) ...[
          const SizedBox(height: 12),
          _monthlyCard(c, monthly, holdDays),
        ],
        // Parrain : 10 % de la valeur des tâches de ses amis, avec une estimation selon le nombre d'amis
        if (sp.isNotEmpty) ...[
          const SizedBox(height: 12),
          _sponsorCard(c, d!, sp, friends),
        ],
        const SizedBox(height: 12),
        if (_loading)
          Center(child: Padding(padding: const EdgeInsets.all(8), child: CircularProgressIndicator(color: c.primary, strokeWidth: 2)))
        else ...[
          Row(children: [
            _amount(c, tr('En attente'), pending, c.info),
            const SizedBox(width: 8),
            _amount(c, tr('Versées'), released, c.primary),
            const SizedBox(width: 8),
            _amount(c, tr('Annulées'), reversed, c.textSecondary),
          ]),
          if (pending > 0 && d?['next_release_at'] != null) ...[
            const SizedBox(height: 8),
            Text(tr('Prochain versement possible : {d}', {'d': _date(d?['next_release_at'])}), style: TextStyle(color: c.textSecondary, fontSize: 12)),
          ],
          if (d?['waiting_for_payment'] == true) ...[
            const SizedBox(height: 6),
            Text(tr('Les premiers versements commencent quand nos partenaires nous ont payés : cela peut prendre plus de {n} jours.', {'n': holdDays}), style: TextStyle(color: c.textSecondary, fontSize: 12, height: 1.35)),
          ],
        ],
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: TextStyle(color: c.warning, fontWeight: FontWeight.w700, fontSize: 13)),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: (_opening || _loading || !enabled) ? null : _open,
            icon: _opening ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.work_outline_rounded),
            label: Text(enabled || _loading ? tr('Voir les tâches') : tr('Les tâches ne sont pas disponibles pour le moment.')),
          ),
        ),
        if (enabled) ...[
          const SizedBox(height: 6),
          Text(_data?['mode'] == 'gallery' ? tr('Une publicité s\'ouvre avant chaque tâche.') : tr('Une publicité peut s\'ouvrir avant la liste des tâches.'), style: TextStyle(color: c.textSecondary.withOpacity(0.8), fontSize: 11)),
        ],
        if (recent.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(tr('Tes tâches récentes'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 6),
          for (final t in recent.take(8))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Expanded(child: Text('${t['offer'] ?? tr('Tâche')}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textPrimary, fontSize: 13))),
                const SizedBox(width: 8),
                Text('${_n.format((t['coins'] as num?)?.toInt() ?? 0)} · ${_statusLabel('${t['status']}')}', style: TextStyle(color: t['status'] == 'released' ? c.primary : c.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600)),
              ]),
            ),
        ],
      ]),
    );
  }
}
