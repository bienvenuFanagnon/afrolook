import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import 'admin_sticker_common.dart';
import 'admin_sticker_detail_page.dart';

/// Fiche d'un pack : aperçu de tous les stickers, créateur, comparaisons avec les originaux
/// et actions Valider / Refuser / Retirer / Rétablir (Cloud Function `adminStickerAction`).
class AdminStickerPackPage extends StatefulWidget {
  final String packId;
  const AdminStickerPackPage({super.key, required this.packId});

  @override
  State<AdminStickerPackPage> createState() => _AdminStickerPackPageState();
}

class _AdminStickerPackPageState extends State<AdminStickerPackPage> {
  bool _busy = false;
  int _reload = 0;

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _stickers() async {
    final q = await FirebaseFirestore.instance.collection('Stickers').where('packId', isEqualTo: widget.packId).get();
    final l = q.docs.toList()..sort((a, b) => ((a.data()['order'] as num?) ?? 0).compareTo((b.data()['order'] as num?) ?? 0));
    return l;
  }

  Future<void> _packAction(String action) async {
    String? reason;
    switch (action) {
      case 'reject':
        reason = await stickerAskReason(context, 'Refuser le pack');
        if (reason == null) return;
        break;
      case 'remove':
        reason = await stickerAskReason(context, 'Retirer le pack');
        if (reason == null) return;
        break;
      case 'approve':
        if (!await stickerConfirm(context, 'Valider le pack', 'Le pack et tous ses stickers seront publiés.')) return;
        break;
      default:
        if (!await stickerConfirm(context, 'Rétablir le pack', 'Le pack et tous ses stickers redeviennent actifs.')) return;
    }
    setState(() => _busy = true);
    final ok = await stickerAdminAction(context, packId: widget.packId, action: action, reason: reason);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) _reload++;
    });
    if (ok) stickerToast(context, 'Action effectuée');
  }

  Future<void> _stickerAction(String id, String action) async {
    String? reason;
    if (action == 'remove') {
      reason = await stickerAskReason(context, 'Retirer ce sticker');
      if (reason == null) return;
    }
    setState(() => _busy = true);
    final ok = await stickerAdminAction(context, stickerId: id, action: action, reason: reason);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) _reload++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        foregroundColor: c.textPrimary,
        elevation: 0,
        title: const Text('Fiche du pack', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: () => setState(() => _reload++))],
      ),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        key: ValueKey('p$_reload'),
        future: FirebaseFirestore.instance.collection('StickerPacks').doc(widget.packId).get(),
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          final p = snap.data?.data();
          if (p == null) return Center(child: Text('Pack introuvable', style: TextStyle(color: c.textSecondary)));
          return _body(c, p);
        },
      ),
    );
  }

  Widget _body(AppColors c, Map<String, dynamic> p) {
    final status = (p['status'] ?? '').toString();
    final creatorId = (p['creatorId'] ?? '').toString();
    final price = (p['priceCoins'] as num?)?.toInt() ?? 0;
    final needsReview = p['needsReview'] == true;
    final reason = (p['rejectReason'] ?? '').toString();
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text((p['name'] ?? '').toString(), style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 4, children: [
              stickerBadge(stickerStatusColor(c, status), stickerStatusLabel(status)),
              if (needsReview) stickerBadge(c.danger, 'Copie possible'),
              stickerBadge(c.info, (p['region'] ?? 'universal').toString()),
            ]),
            const SizedBox(height: 8),
            Text(
              '${(p['stickerCount'] as num?)?.toInt() ?? 0} stickers · ${price == 0 ? 'Gratuit' : '$price pièces'} · ${(p['salesCount'] as num?)?.toInt() ?? 0} ventes',
              style: TextStyle(color: c.textSecondary, fontSize: 12.5),
            ),
            Text('Déposé le ${stickerDate(p['createdAt'])}', style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
            if (reason.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Motif : $reason', style: TextStyle(color: c.danger, fontSize: 12.5))),
            const Divider(height: 22),
            Row(children: [
              Text('Créateur : ', style: TextStyle(color: c.textSecondary, fontSize: 13)),
              Flexible(
                child: InkWell(
                  onTap: creatorId == 'afrolook' ? null : () => stickerOpenUser(context, creatorId),
                  child: StickerPseudoText(creatorId, style: TextStyle(color: creatorId == 'afrolook' ? c.textPrimary : c.info, fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ),
              if (creatorId != 'afrolook') Icon(Icons.chevron_right_rounded, size: 18, color: c.info),
            ]),
          ]),
        ),
        const SizedBox(height: 14),
        Text('Stickers du pack', style: TextStyle(color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
          key: ValueKey('s$_reload'),
          future: _stickers(),
          builder: (ctx, snap) {
            if (snap.connectionState != ConnectionState.done) return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()));
            final docs = snap.data ?? [];
            if (docs.isEmpty) return Text('Aucun sticker', style: TextStyle(color: c.textSecondary));
            return Column(children: [for (final d in docs) _stickerCard(c, d)]);
          },
        ),
        const SizedBox(height: 16),
        _actions(c, status),
      ],
    );
  }

  Widget _stickerCard(AppColors c, QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final s = d.data();
    final st = (s['status'] ?? '').toString();
    final gift = (s['giftPriceCoins'] as num?)?.toInt() ?? 0;
    final caption = stickerCaption(s);
    final isCopy = (s['copyOf'] ?? '').toString().isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isCopy ? c.danger.withOpacity(0.5) : c.border),
      ),
      child: Column(children: [
        InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminStickerDetailPage(stickerId: d.id))),
          child: Row(children: [
            StickerThumbBox(s, size: 72, animated: true),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(caption.isEmpty ? '(sans légende)' : caption, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 13.5)),
                const SizedBox(height: 4),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  stickerBadge(c.info, (s['category'] ?? '—').toString()),
                  stickerBadge(stickerStatusColor(c, st), stickerStatusLabel(st)),
                  if (gift > 0) stickerBadge(c.warning, 'Cadeau $gift pièces'),
                  if (isCopy) stickerBadge(c.danger, 'Copie possible'),
                ]),
              ]),
            ),
            PopupMenuButton<String>(
              onSelected: _busy ? null : (a) => _stickerAction(d.id, a),
              itemBuilder: (_) => [
                if (st != 'removed' && st != 'rejected') const PopupMenuItem(value: 'remove', child: Text('Retirer ce sticker')),
                if (st == 'removed' || st == 'rejected') const PopupMenuItem(value: 'restore', child: Text('Rétablir ce sticker')),
              ],
            ),
          ]),
        ),
        if (isCopy) StickerCompareView(stickerId: d.id, sticker: s),
      ]),
    );
  }

  Widget _actions(AppColors c, String status) {
    Widget btn(String label, IconData icon, Color color, String action) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ElevatedButton.icon(
              onPressed: _busy ? null : () => _packAction(action),
              icon: Icon(icon, size: 18),
              label: Text(label),
              style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
            ),
          ),
        );
    final list = <Widget>[];
    if (status == 'pending') {
      list.addAll([btn('Valider', Icons.check_rounded, c.primary, 'approve'), btn('Refuser', Icons.close_rounded, c.danger, 'reject')]);
    } else if (status == 'active') {
      list.add(btn('Retirer', Icons.block_rounded, c.danger, 'remove'));
    } else {
      list.add(btn('Rétablir', Icons.restore_rounded, c.primary, 'restore'));
    }
    return Column(children: [
      if (_busy) const Padding(padding: EdgeInsets.only(bottom: 8), child: LinearProgressIndicator()),
      Row(children: list),
    ]);
  }
}
