import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../ads/ad_slot.dart';
import '../../layout/centered_content.dart';
import '../../l10n/tr.dart';
import '../../providers/authProvider.dart';
import '../../services/share/share_service.dart';
import '../../theme/app_colors.dart';
import '../user/inviteAmis.dart';

/// Page « Partage et gagne » : on partage des annonces (statut WhatsApp, groupes, Telegram, Facebook, TikTok…) avec son lien personnel et on est payé en pièces
/// pour chaque clic VALIDE. Le texte explique les gains, le parrainage et la consigne à respecter, sans détails techniques.
class ShareEarnPage extends StatefulWidget {
  const ShareEarnPage({super.key});

  @override
  State<ShareEarnPage> createState() => _ShareEarnPageState();
}

class _ShareEarnPageState extends State<ShareEarnPage> {
  ShareHome? _home;
  String? _error;
  bool _loading = true;
  String? _busyMission;

  UserAuthProvider get _auth => Provider.of<UserAuthProvider>(context, listen: false);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final h = await ShareService.load();
      if (!mounted) return;
      setState(() { _home = h; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      // Service injoignable : on montre quand même les informations du travail (gains, parrainage, consigne).
      setState(() { _home = ShareHome.preview(); _loading = false; });
    }
  }

  NumberFormat _fmt(String pattern) => NumberFormat(pattern, Localizations.localeOf(context).toString());
  String _n(num v) => _fmt('#,##0.#').format(v);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(backgroundColor: c.surface, foregroundColor: c.textPrimary, title: Text(context.tr('Partage et gagne'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, style: TextStyle(color: c.textSecondary), textAlign: TextAlign.center)))
              : RefreshIndicator(onRefresh: _load, child: _content(c, _home!)),
    );
  }

  Widget _content(AppColors c, ShareHome h) {
    if (!h.enabled) {
      return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
        CenteredContent(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _hero(c),
            _ad(AdSlotKind.detail),
            _card(c, [
              _title(c, Icons.schedule_rounded, context.tr('Bientôt disponible')),
              const SizedBox(height: 6),
              Text(context.tr('Partage des annonces et gagne des pièces pour chaque clic. Reviens très vite !'), style: TextStyle(color: c.textSecondary, fontSize: 13.5, height: 1.4)),
            ]),
            const SizedBox(height: 12),
            _earnCard(c, h),
            const SizedBox(height: 12),
            _sponsorCard(c, h),
            const SizedBox(height: 12),
            _rulesCard(c, h),
            _ad(AdSlotKind.list),
          ]),
        ),
      ]);
    }
    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
      CenteredContent(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _hero(c),
          _ad(AdSlotKind.detail),
          _earnCard(c, h),
          const SizedBox(height: 12),
          _sponsorCard(c, h),
          const SizedBox(height: 12),
          _rulesCard(c, h),
          _ad(AdSlotKind.list),
          _profileCard(c, h),
          if (h.status == 'active') ...[
            const SizedBox(height: 12),
            _missions(c, h),
            const SizedBox(height: 12),
            _myEarnings(c, h),
            _ad(AdSlotKind.detail),
          ],
        ]),
      ),
    ]);
  }

  /// Emplacement publicitaire : réseaux seulement (AdMob / Appodeal), jamais de pub Afrolook gratuite ici ; vide pour les comptes sans pub.
  Widget _ad(AdSlotKind kind) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: AdSlot(kind: kind, own: () => const SizedBox.shrink(), admobFirst: true, allowOwn: false),
      );

  Widget _card(AppColors c, List<Widget> children, {Color? color}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: color ?? c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  Widget _title(AppColors c, IconData icon, String text) => Row(children: [
        Icon(icon, color: c.primary, size: 22),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(color: c.textPrimary, fontSize: 16.5, fontWeight: FontWeight.w800))),
      ]);

  Widget _hero(AppColors c) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(gradient: LinearGradient(colors: [c.primary, c.primary.withOpacity(0.75)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(context.tr('Partage des annonces, gagne des pièces'), style: TextStyle(color: c.onPrimary, fontSize: 21, fontWeight: FontWeight.w900, height: 1.2)),
          const SizedBox(height: 8),
          Text(context.tr('Publie une annonce sur ton statut WhatsApp, tes groupes, Telegram, Facebook ou TikTok. Chaque personne qui clique sur ton lien te rapporte de l\'argent : tes gains arrivent en pièces, que tu convertis en FCFA.'), style: TextStyle(color: c.onPrimary, fontSize: 13.5, height: 1.4)),
        ]),
      );

  /// Gains : valeur d'un clic, exemples, plafond du jour et estimation selon l'audience (estimation, jamais une promesse).
  Widget _earnCard(AppColors c, ShareHome h) {
    final per = h.coinsPerClick, cap = h.maxClicksPerDay;
    final estClicks = h.retained > 0 ? (h.retained * h.expectedCtr).round() : (500 * h.expectedCtr).round();
    Widget row(String left, String right) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [Expanded(child: Text(left, style: TextStyle(color: c.textSecondary, fontSize: 13.5))), Text(right, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 13.5))]),
        );
    return _card(c, [
      _title(c, Icons.savings_rounded, context.tr('Combien tu peux gagner')),
      const SizedBox(height: 10),
      Text(context.tr('{f} F par clic valide', {'f': _n(h.perClickFcfa)}), style: TextStyle(color: c.primary, fontSize: 24, fontWeight: FontWeight.w900)),
      Text(context.tr('soit {c} pièces pour chaque personne qui clique, converties en argent réel (FCFA)', {'c': _n(per)}), style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
      const SizedBox(height: 10),
      row(context.tr('10 clics'), context.tr('{f} F', {'f': _n(h.perClickFcfa * 10)})),
      row(context.tr('50 clics'), context.tr('{f} F', {'f': _n(h.perClickFcfa * (cap > 0 && cap < 50 ? cap : 50))})),
      if (cap > 0) row(context.tr('Maximum par jour ({n} clics)', {'n': cap}), context.tr('{f} F', {'f': _n(h.perClickFcfa * cap)})),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: c.surfaceVariant, borderRadius: BorderRadius.circular(12)),
        child: Text(
          h.retained > 0
              ? context.tr('Avec ton audience validée ({a} personnes), tu peux espérer environ {n} clics par annonce partagée, soit environ {f} F. C\'est une estimation, sans garantie.', {'a': _n(h.retained), 'n': estClicks, 'f': _n(h.perClickFcfa * estClicks)})
              : context.tr('Exemple : avec 500 personnes qui voient tes statuts et tes groupes, on peut espérer environ {n} clics par annonce, soit environ {f} F. C\'est une estimation, sans garantie.', {'n': estClicks, 'f': _n(h.perClickFcfa * estClicks)}),
          style: TextStyle(color: c.textPrimary, fontSize: 12.5, height: 1.4),
        ),
      ),
      const SizedBox(height: 8),
      Text(context.tr('Plus ton audience est grande et active, plus tu gagnes. Tes gains sont d\'abord « en attente » pendant {h} h, puis ajoutés à ton solde de pièces, que tu convertis en argent réel (FCFA).', {'h': h.holdHours}), style: TextStyle(color: c.textSecondary, fontSize: 12, height: 1.35)),
    ]);
  }

  Widget _sponsorCard(AppColors c, ShareHome h) => _card(c, [
        _title(c, Icons.group_add_rounded, context.tr('Le parrainage rapporte aussi')),
        const SizedBox(height: 8),
        Text(
          context.tr('Quand un ami que tu as parrainé gagne des pièces avec le partage, tu reçois en plus {p} % de ses gains. Cela ne diminue jamais les siens : c\'est Afrolook qui l\'ajoute. Plus tes amis partagent, plus tu gagnes sans rien faire.', {'p': h.sponsorPct}),
          style: TextStyle(color: c.textPrimary, fontSize: 13.5, height: 1.4),
        ),
        const SizedBox(height: 6),
        Text(context.tr('Exemple : s\'il gagne 100 F, tu reçois en plus {x} F.', {'x': _n(h.sponsorPct)}), style: TextStyle(color: c.primary, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () => showInviteFriendsModal(context, _auth.loginUserData), icon: const Icon(Icons.share_rounded), label: Text(context.tr('Inviter mes amis')))),
      ]);

  /// La même consigne pour tous les partages, sur toutes les plateformes. Courte et sans détails techniques.
  Widget _rulesCard(AppColors c, ShareHome h) {
    Widget item(IconData icon, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 18, color: c.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: TextStyle(color: c.textPrimary, fontSize: 13.5, height: 1.35))),
          ]),
        );
    return _card(c, [
      _title(c, Icons.rule_rounded, context.tr('La consigne, la même partout')),
      const SizedBox(height: 6),
      item(Icons.campaign_rounded, context.tr('Diffuse l\'annonce où tu veux : WhatsApp, Telegram, Facebook, TikTok… avec ton lien personnel.')),
      item(Icons.ads_click_rounded, context.tr('Seuls les clics valides sont payés : une vraie personne qui clique, une seule fois. Pas de doublon.')),
      item(Icons.block_rounded, context.tr('Ne clique pas toi-même et ne fais pas cliquer en boucle : chaque fraude est détectée et n\'est pas comptée.')),
      item(Icons.undo_rounded, context.tr('Un gain peut être retiré si nos contrôles détectent une fraude venant de ton compte.')),
      item(Icons.pan_tool_alt_rounded, context.tr('Publie toi-même, sans spam : jamais d\'envoi en masse à des personnes qui ne t\'ont rien demandé.')),
      if (h.rules.isNotEmpty)
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(context.tr('Lire toutes les règles'), style: TextStyle(color: c.primary, fontWeight: FontWeight.w700, fontSize: 13.5)),
            children: [
              for (final b in h.rules) ...[
                Align(alignment: Alignment.centerLeft, child: Text('${b['title']}', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 13))),
                for (final i in (b['items'] as List)) Padding(padding: const EdgeInsets.only(top: 3, bottom: 3), child: Text('• $i', style: TextStyle(color: c.textSecondary, fontSize: 12.5, height: 1.35))),
                const SizedBox(height: 6),
              ],
            ],
          ),
        ),
    ]);
  }

  Widget _profileCard(AppColors c, ShareHome h) {
    final s = h.status;
    final (IconData icon, Color color, String title, String text) = switch (s) {
      'active' => (Icons.verified_rounded, c.primary, context.tr('Profil validé'), context.tr('Ton audience validée : {a} personnes. Tu peux partager les annonces ci-dessous.', {'a': _n(h.retained)})),
      'pending' => (Icons.hourglass_top_rounded, c.warning, context.tr('Profil en cours de validation'), context.tr('Notre équipe vérifie ton audience. Tu pourras commencer dès qu\'il est validé.')),
      'refused' => (Icons.cancel_rounded, c.danger, context.tr('Profil refusé'), h.profile?.reason.isNotEmpty == true ? h.profile!.reason : context.tr('Corrige ton profil puis renvoie-le.')),
      'suspended' => (Icons.block_rounded, c.danger, context.tr('Profil suspendu'), h.profile?.reason.isNotEmpty == true ? h.profile!.reason : context.tr('Ton profil est suspendu. Contacte-nous pour en savoir plus.')),
      _ => (Icons.edit_note_rounded, c.info, context.tr('Crée ton profil pour commencer'), context.tr('Dis-nous combien de personnes voient tes statuts et tes groupes. Notre équipe valide ton profil avant ta première mission.')),
    };
    return _card(c, [
      Row(children: [Icon(icon, color: color), const SizedBox(width: 10), Expanded(child: Text(title, style: TextStyle(color: c.textPrimary, fontSize: 16.5, fontWeight: FontWeight.w800)))]),
      const SizedBox(height: 6),
      Text(text, style: TextStyle(color: c.textSecondary, fontSize: 13.5, height: 1.4)),
      if (s != 'suspended') ...[
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: s == 'none' || s == 'refused' ? FilledButton.icon(onPressed: () => _editProfile(h), icon: const Icon(Icons.person_add_alt_1_rounded), label: Text(s == 'none' ? context.tr('Créer mon profil') : context.tr('Corriger mon profil'))) : OutlinedButton(onPressed: () => _editProfile(h), child: Text(context.tr('Modifier mon profil'))),
        ),
      ],
    ]);
  }

  Widget _missions(AppColors c, ShareHome h) {
    if (h.missions.isEmpty) {
      return _card(c, [
        _title(c, Icons.inbox_rounded, context.tr('Missions disponibles')),
        const SizedBox(height: 8),
        Text(context.tr('Aucune annonce à partager pour le moment. De nouvelles arrivent régulièrement : reviens bientôt.'), style: TextStyle(color: c.textSecondary, fontSize: 13.5)),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(bottom: 8), child: _title(c, Icons.local_fire_department_rounded, context.tr('Missions disponibles'))),
      for (var i = 0; i < h.missions.length; i++) ...[
        _missionCard(c, h.missions[i]),
        if (i % 2 == 1 && i < h.missions.length - 1) _ad(AdSlotKind.list),
      ],
    ]);
  }

  /// Résultats de la mission : publication confirmée, personnes qui ont ouvert le lien, clics valides, vues déclarées.
  Widget _results(AppColors c, ShareMission m) {
    final r = m.results!;
    num n(String k) => (r[k] as num?) ?? 0;
    final published = n('published') > 0;
    Widget stat(String value, String label) => Expanded(child: Column(children: [Text(value, style: TextStyle(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w900)), const SizedBox(height: 2), Text(label, textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary, fontSize: 11))]));
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: c.surfaceVariant, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(published ? Icons.verified_rounded : Icons.hourglass_top_rounded, size: 17, color: published ? c.primary : c.textSecondary),
          const SizedBox(width: 6),
          Expanded(child: Text(published ? context.tr('Publication confirmée : une personne a ouvert ton lien.') : context.tr('En attente : ta publication sera confirmée dès qu\'une personne ouvrira ton lien.'), style: TextStyle(color: c.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 8),
        Row(children: [stat(_n(n('opens')), context.tr('personnes ont ouvert')), stat(_n(n('valid')), context.tr('clics valides')), stat(_n(n('views')), context.tr('vues déclarées'))]),
        const SizedBox(height: 6),
        Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: () => _askViews(m), icon: const Icon(Icons.visibility_rounded, size: 16), label: Text(context.tr('Déclarer mes vues')))),
      ]),
    );
  }

  /// Le partageur indique le nombre de vues de sa publication (ex. « Vu par … » du statut WhatsApp). Chiffre déclaré : contrôlé, jamais présenté comme mesuré.
  Future<void> _askViews(ShareMission m) async {
    final ctl = TextEditingController();
    final views = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Combien de personnes ont vu ta publication ?')),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(context.tr('Par exemple le nombre de « vues » de ton statut WhatsApp. Sois honnête : ce chiffre est contrôlé avec les ouvertures de ton lien.'), style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 10),
          TextField(controller: ctl, keyboardType: TextInputType.number, autofocus: true, decoration: InputDecoration(border: const OutlineInputBorder(), hintText: context.tr('Nombre de vues'))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('Annuler'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, int.tryParse(ctl.text.trim())), child: Text(context.tr('Envoyer'))),
        ],
      ),
    );
    if (views == null || !mounted) return;
    try {
      final r = await ShareService.reportViews(m.id, views);
      if (!mounted) return;
      final msg = r['counted'] == true
          ? context.tr('Merci, tes vues sont enregistrées.')
          : r['plausible'] != true
              ? context.tr('Ce chiffre paraît trop élevé par rapport à ton audience validée : notre équipe va le vérifier.')
              : context.tr('Enregistré. Il sera compté dès qu\'une personne aura ouvert ton lien.');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ShareService.explain(e, (s) => context.tr(s)))));
    }
  }

  /// Détail d'une mission : annonce en entier, gain par clic en FCFA, bannière, puis le bouton de partage.
  Future<void> _showDetail(ShareMission m) async {
    final c = AppColors.of(context);
    final go = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.surface,
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (m.image.isNotEmpty)
              ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(height: 220, width: double.infinity, child: CachedNetworkImage(imageUrl: m.image, fit: BoxFit.contain, errorWidget: (_, __, ___) => Container(color: c.surfaceVariant)))),
            const SizedBox(height: 12),
            if (m.brand.isNotEmpty) Text(m.brand, style: TextStyle(color: c.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w700)),
            Text(m.title, style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
            if (m.text.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(m.text, style: TextStyle(color: c.textPrimary, fontSize: 14, height: 1.4))),
            const SizedBox(height: 12),
            Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: c.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(99)), child: Text(context.tr('+{f} F par clic', {'f': _n(m.fcfaPerClick)}), style: TextStyle(color: c.primary, fontWeight: FontWeight.w800, fontSize: 13))),
            _ad(AdSlotKind.detail),
            SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => Navigator.pop(ctx, true), icon: const Icon(Icons.ios_share_rounded, size: 18), label: Text(context.tr('Partager')))),
          ]),
        ),
      ),
    );
    if (go == true && mounted) await _chooseChannel(m);
  }

  Widget _missionCard(AppColors c, ShareMission m) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: () => _showDetail(m), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (m.image.isNotEmpty)
            SizedBox(
              height: 170, width: double.infinity,
              child: Stack(fit: StackFit.expand, children: [
                CachedNetworkImage(imageUrl: m.image, fit: BoxFit.contain, errorWidget: (_, __, ___) => Container(color: c.surfaceVariant)),
                if (m.video) const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white70, size: 46)),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (m.brand.isNotEmpty) Text(m.brand, style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
              Text(m.title, style: TextStyle(color: c.textPrimary, fontSize: 15.5, fontWeight: FontWeight.w800)),
              if (m.text.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(m.text, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.35))),
              if (m.results != null) _results(c, m),
              const SizedBox(height: 10),
              Row(children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: c.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(99)), child: Text(context.tr('+{f} F par clic', {'f': _n(m.fcfaPerClick)}), style: TextStyle(color: c.primary, fontWeight: FontWeight.w800, fontSize: 12.5))),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _busyMission == null ? () => _chooseChannel(m) : null,
                  icon: _busyMission == m.id ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.ios_share_rounded, size: 18),
                  label: Text(context.tr('Partager')),
                ),
              ]),
            ]),
          ),
        ])),
      );

  Widget _myEarnings(AppColors c, ShareHome h) {
    Widget cell(String value, String label) => Expanded(child: Column(children: [Text(value, style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 2), Text(label, textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary, fontSize: 11.5))]));
    return _card(c, [
      _title(c, Icons.insights_rounded, context.tr('Mes gains de partage')),
      const SizedBox(height: 12),
      Row(children: [
        cell(_n(h.validClicks), context.tr('clics valides')),
        cell(_n(h.pendingFcfa * 2.5), context.tr('pièces en attente')),
        cell(_n(h.paidCoins), context.tr('pièces gagnées')),
      ]),
      const SizedBox(height: 10),
      Text(context.tr('Soit environ {f} F déjà gagnés, convertibles en argent réel.', {'f': _n(h.paidCoins / 2.5)}), style: TextStyle(color: c.primary, fontSize: 13, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text(context.tr('Aujourd\'hui : {f} F sur un maximum de {m} F par jour.', {'f': _n(h.todayFcfa), 'm': _n(h.dailyCapFcfa)}), style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
    ]);
  }

  // ─── Partager ─────────────────────────────────────────────────────────────────────────────────────────────────────────

  static const _channels = <(String, String, IconData)>[
    ('whatsapp_status', 'Mon statut WhatsApp', Icons.circle_outlined),
    ('whatsapp_group', 'Un groupe WhatsApp', Icons.groups_rounded),
    ('telegram_group', 'Un groupe Telegram', Icons.send_rounded),
    ('telegram_channel', 'Mon canal Telegram', Icons.campaign_rounded),
    ('facebook', 'Facebook', Icons.facebook_rounded),
    ('tiktok', 'TikTok', Icons.music_note_rounded),
    ('other', 'Un autre endroit', Icons.more_horiz_rounded),
  ];

  Future<void> _chooseChannel(ShareMission m) async {
    final c = AppColors.of(context);
    final channel = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.tr('Où vas-tu partager ?'), style: TextStyle(color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(context.tr('Ton lien personnel marche partout. Choisir l\'endroit nous aide à savoir ce qui marche le mieux.'), style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
            const SizedBox(height: 8),
            for (final ch in _channels)
              ListTile(contentPadding: EdgeInsets.zero, leading: Icon(ch.$3, color: c.primary), title: Text(context.tr(ch.$2), style: TextStyle(color: c.textPrimary)), onTap: () => Navigator.pop(ctx, ch.$1)),
          ]),
        ),
      ),
    );
    if (channel != null) await _share(m, channel);
  }

  Future<void> _share(ShareMission m, String channel) async {
    setState(() => _busyMission = m.id);
    try {
      final lang = Localizations.localeOf(context).languageCode == 'fr' ? 'fr' : 'en';
      final link = await ShareService.createLink(m.id, channel, lang);
      if (!mounted) return;
      if (kIsWeb || link.mediaUrl.isEmpty) {
        await Share.share(link.caption);
      } else {
        final file = await _download(link.mediaUrl, link.video);
        await Share.shareXFiles([XFile(file.path)], text: link.caption);
      }
      if (mounted) await _load(); // met à jour les chiffres
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ShareService.explain(e, (s) => context.tr(s)))));
    } finally {
      if (mounted) setState(() => _busyMission = null);
    }
  }

  Future<File> _download(String url, bool video) async {
    final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 60));
    if (res.statusCode != 200) throw StateError('téléchargement impossible');
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/afrolook_partage_${DateTime.now().millisecondsSinceEpoch}.${video ? 'mp4' : 'jpg'}');
    return f.writeAsBytes(res.bodyBytes);
  }

  // ─── Profil ───────────────────────────────────────────────────────────────────────────────────────────────────────────

  Future<void> _editProfile(ShareHome h) async {
    final done = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => _ProfileForm(home: h, defaultCountry: '${_auth.loginUserData.countryData?['countryCode'] ?? ''}')));
    if (done == true) _load();
  }
}

class _ProfileForm extends StatefulWidget {
  const _ProfileForm({required this.home, required this.defaultCountry});
  final ShareHome home;
  final String defaultCountry;

  @override
  State<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<_ProfileForm> {
  final _wa = TextEditingController();
  late final TextEditingController _country = TextEditingController(text: widget.defaultCountry.toUpperCase());
  final _city = TextEditingController();
  final _status = TextEditingController(text: '0');
  final _tg = TextEditingController(text: '0');
  final _other = TextEditingController(text: '0');
  final _about = TextEditingController();
  final List<(TextEditingController, TextEditingController)> _groups = [];
  bool _accept = false;
  bool _busy = false;
  String? _err;

  @override
  void dispose() {
    for (final x in [_wa, _country, _city, _status, _tg, _other, _about]) { x.dispose(); }
    for (final g in _groups) { g.$1.dispose(); g.$2.dispose(); }
    super.dispose();
  }

  Widget _field(AppColors c, String label, TextEditingController ctl, {TextInputType? type, int lines = 1, int? max, String? hint}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(controller: ctl, keyboardType: type, minLines: lines, maxLines: lines, maxLength: max, decoration: InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder(), counterText: '')),
      );

  Future<void> _send() async {
    // contrôles avant l'envoi : mêmes règles que le serveur, avec des messages simples
    final total = (int.tryParse(_status.text.trim()) ?? 0) + (int.tryParse(_tg.text.trim()) ?? 0) + (int.tryParse(_other.text.trim()) ?? 0) + [for (final g in _groups) if (g.$1.text.trim().isNotEmpty) int.tryParse(g.$2.text.trim()) ?? 0].fold<int>(0, (a, b) => a + b);
    final wa = _wa.text.replaceAll(RegExp(r'[\s().-]'), '');
    String? bad;
    if (!RegExp(r'^\+\d{8,15}$').hasMatch(wa)) {
      bad = context.tr('Ton numéro WhatsApp n\'est pas valide. Écris-le avec l\'indicatif du pays, par exemple +22890123456.');
    } else if (!RegExp(r'^[A-Za-z]{2}$').hasMatch(_country.text.trim())) {
      bad = context.tr('Le pays s\'écrit avec 2 lettres, par exemple TG pour le Togo.');
    } else if (total < 20) {
      bad = context.tr('Ton audience doit compter au moins 20 personnes (statut, canal, groupes).');
    } else if (_about.text.trim().length < 20) {
      bad = context.tr('Présente ton audience en 20 caractères au moins : qui sont-ils, que partages-tu d\'habitude ?');
    }
    if (bad != null) {
      setState(() => _err = bad);
      return;
    }
    setState(() { _busy = true; _err = null; });
    try {
      final status = await ShareService.saveProfile({
        'whatsapp': _wa.text.trim(), 'country': _country.text.trim(), 'city': _city.text.trim(),
        'statusAudience': int.tryParse(_status.text.trim()) ?? 0, 'telegramAudience': int.tryParse(_tg.text.trim()) ?? 0, 'otherAudience': int.tryParse(_other.text.trim()) ?? 0,
        'groups': [for (final g in _groups) if (g.$1.text.trim().isNotEmpty) {'name': g.$1.text.trim(), 'members': int.tryParse(g.$2.text.trim()) ?? 0}],
        'about': _about.text.trim(), 'acceptTerms': _accept, 'rulesVersion': widget.home.rulesVersion,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(status == 'active' ? context.tr('Profil mis à jour.') : context.tr('Profil envoyé : notre équipe le valide, tu seras prévenu.'))));
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() { _err = ShareService.profileError(e, (s) => context.tr(s)); _busy = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(backgroundColor: c.surface, foregroundColor: c.textPrimary, title: Text(context.tr('Mon profil partageur'))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(context.tr('Dis-nous combien de personnes voient tes publications. Sois honnête : une audience gonflée fait refuser ou suspendre le profil.'), style: TextStyle(color: c.textSecondary, fontSize: 13.5, height: 1.4)),
        const SizedBox(height: 14),
        _field(c, context.tr('Ton numéro WhatsApp'), _wa, type: TextInputType.phone, hint: '+22890123456'),
        Row(children: [
          Expanded(child: _field(c, context.tr('Pays (2 lettres)'), _country, max: 2, hint: 'TG')),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: _field(c, context.tr('Ville'), _city)),
        ]),
        _field(c, context.tr('Personnes qui voient ton statut WhatsApp'), _status, type: TextInputType.number),
        _field(c, context.tr('Abonnés de ton canal Telegram'), _tg, type: TextInputType.number),
        _field(c, context.tr('Autres réseaux (Facebook, TikTok…) : abonnés'), _other, type: TextInputType.number),
        Text(context.tr('Tes groupes (WhatsApp, Telegram)'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        for (var i = 0; i < _groups.length; i++)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 2, child: _field(c, context.tr('Nom du groupe'), _groups[i].$1, max: 40)),
            const SizedBox(width: 8),
            Expanded(child: _field(c, context.tr('Membres'), _groups[i].$2, type: TextInputType.number)),
            IconButton(onPressed: () => setState(() { final g = _groups.removeAt(i); g.$1.dispose(); g.$2.dispose(); }), icon: const Icon(Icons.close_rounded)),
          ]),
        if (_groups.length < 15) Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () => setState(() => _groups.add((TextEditingController(), TextEditingController()))), icon: const Icon(Icons.add_rounded), label: Text(context.tr('Ajouter un groupe')))),
        const SizedBox(height: 6),
        _field(c, context.tr('Présente ton audience (qui sont-ils, que partages-tu ?)'), _about, lines: 3, max: 400),
        CheckboxListTile(
          value: _accept, onChanged: (v) => setState(() => _accept = v == true), contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading,
          title: Text(context.tr('J\'ai lu et j\'accepte les règles : seuls les clics valides sont payés, pas de doublon, les fraudes ne sont pas comptées et un gain peut être retiré.'), style: TextStyle(color: c.textPrimary, fontSize: 13)),
        ),
        if (_err != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_err!, style: TextStyle(color: c.danger, fontWeight: FontWeight.w700))),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: _busy || !_accept ? null : _send, child: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(context.tr('Envoyer mon profil')))),
      ]),
    );
  }
}
