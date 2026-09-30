import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import 'admin_sticker_common.dart';

/// Fiche d'un sticker du catalogue : aperçu, infos, propriétaire, comparaison avec l'origine,
/// signalements, historique des actions admin, et Retirer / Rétablir.
class AdminStickerDetailPage extends StatefulWidget {
  final String stickerId;
  const AdminStickerDetailPage({super.key, required this.stickerId});

  @override
  State<AdminStickerDetailPage> createState() => _AdminStickerDetailPageState();
}

class _AdminStickerDetailPageState extends State<AdminStickerDetailPage> {
  bool _busy = false;
  int _reload = 0;

  Future<_Extra> _loadExtra(Map<String, dynamic> s) async {
    final db = FirebaseFirestore.instance;
    var reports = 0;
    try {
      final r = await db.collection('StickerReports').where('stickerId', isEqualTo: widget.stickerId).count().get();
      reports = r.count ?? 0;
    } catch (_) {}
    final actions = <Map<String, dynamic>>[];
    try {
      final ids = <String>{widget.stickerId, if ((s['packId'] ?? '').toString().isNotEmpty) s['packId'].toString()};
      for (final id in ids) {
        final q = await db.collection('AdminActions').where('targetId', isEqualTo: id).limit(50).get();
        actions.addAll(q.docs.map((d) => d.data()));
      }
      actions.sort((a, b) => ((b['at'] as num?) ?? 0).compareTo((a['at'] as num?) ?? 0));
    } catch (_) {}
    return _Extra(reports, actions);
  }

  Future<void> _act(String action) async {
    String? reason;
    if (action == 'remove') {
      reason = await stickerAskReason(context, 'Retirer ce sticker');
      if (reason == null) return;
    } else if (!await stickerConfirm(context, 'Rétablir ce sticker', 'Le sticker redevient utilisable.')) {
      return;
    }
    setState(() => _busy = true);
    final ok = await stickerAdminAction(context, stickerId: widget.stickerId, action: action, reason: reason);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) _reload++;
    });
    if (ok) stickerToast(context, action == 'remove' ? 'Sticker retiré' : 'Sticker rétabli');
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
        title: const Text('Fiche du sticker', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: () => setState(() => _reload++))],
      ),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        key: ValueKey(_reload),
        future: FirebaseFirestore.instance.collection('Stickers').doc(widget.stickerId).get(),
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          final s = snap.data?.data();
          if (s == null) return Center(child: Text('Sticker introuvable', style: TextStyle(color: c.textSecondary)));
          return _body(c, s);
        },
      ),
    );
  }

  Widget _body(AppColors c, Map<String, dynamic> s) {
    final status = (s['status'] ?? '').toString();
    final gift = (s['giftPriceCoins'] as num?)?.toInt() ?? 0;
    final creatorId = (s['creatorId'] ?? '').toString();
    final caption = stickerCaption(s);
    final captions = s['captions'] is Map ? Map<String, dynamic>.from(s['captions'] as Map) : <String, dynamic>{};
    Widget row(String k, Widget v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 130, child: Text(k, style: TextStyle(color: c.textSecondary, fontSize: 12.5))),
            Expanded(child: v),
          ]),
        );
    Widget txt(String t) => Text(t, style: TextStyle(color: c.textPrimary, fontSize: 13, fontWeight: FontWeight.w600));
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
      children: [
        Center(child: StickerThumbBox(s, size: 200, animated: true)),
        const SizedBox(height: 10),
        Center(child: stickerBadge(stickerStatusColor(c, status), stickerStatusLabel(status))),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
          child: Column(children: [
            row('Identifiant', SelectableText(widget.stickerId, style: TextStyle(color: c.textPrimary, fontSize: 12))),
            row('Légende (fr)', txt(caption.isEmpty ? '—' : caption)),
            if (captions.length > 1)
              row('Autres langues', txt(captions.entries.map((e) => '${e.key} : ${e.value}').join('\n'))),
            row('Catégorie', txt((s['category'] ?? '—').toString())),
            row('Pack', StickerPackNameText(s['packId']?.toString(), style: TextStyle(color: c.textPrimary, fontSize: 13, fontWeight: FontWeight.w600))),
            row('Déposé le', txt(stickerDate(s['createdAt']))),
            row('Utilisations', txt('${(s['usageCount'] as num?)?.toInt() ?? 0}')),
            row('Cadeaux envoyés', txt('${(s['giftCount'] as num?)?.toInt() ?? 0}')),
            row('Prix cadeau', txt(gift > 0 ? '$gift pièces' : 'Sticker normal')),
            row('Poids', txt('${(((s['sizeBytes'] as num?) ?? 0) / 1024).round()} Ko${s['animated'] == true ? ' · animé' : ''}')),
            if ((s['rejectReason'] ?? '').toString().isNotEmpty) row('Motif', txt(s['rejectReason'].toString())),
            row(
              'Propriétaire',
              InkWell(
                onTap: creatorId == 'afrolook' ? null : () => stickerOpenUser(context, creatorId),
                child: Row(children: [
                  Flexible(child: StickerPseudoText(creatorId, style: TextStyle(color: creatorId == 'afrolook' ? c.textPrimary : c.info, fontSize: 13, fontWeight: FontWeight.w700))),
                  if (creatorId != 'afrolook') Icon(Icons.chevron_right_rounded, size: 18, color: c.info),
                ]),
              ),
            ),
          ]),
        ),
        StickerCompareView(stickerId: widget.stickerId, sticker: s),
        const SizedBox(height: 12),
        FutureBuilder<_Extra>(
          key: ValueKey('x$_reload'),
          future: _loadExtra(s),
          builder: (ctx, es) {
            final e = es.data;
            if (e == null) return const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()));
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
                child: Row(children: [
                  Icon(Icons.flag_rounded, color: e.reports > 0 ? c.danger : c.textSecondary, size: 20),
                  const SizedBox(width: 10),
                  Text('${e.reports} signalement(s)', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700)),
                ]),
              ),
              const SizedBox(height: 12),
              Text('Historique des actions admin', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              if (e.actions.isEmpty)
                Text('Aucune action enregistrée', style: TextStyle(color: c.textSecondary, fontSize: 12.5))
              else
                for (final a in e.actions)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(Icons.history_rounded, size: 16, color: c.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${stickerDate(a['at'])} · ${a['targetType'] == 'sticker_pack' ? 'pack' : 'sticker'} · ${a['action']}'
                          '${(a['reason'] ?? '').toString().isEmpty ? '' : ' · ${a['reason']}'}',
                          style: TextStyle(color: c.textSecondary, fontSize: 12.5),
                        ),
                      ),
                    ]),
                  ),
            ]);
          },
        ),
        const SizedBox(height: 18),
        Row(children: [
          if (status != 'removed' && status != 'rejected')
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _busy ? null : () => _act('remove'),
                icon: const Icon(Icons.block_rounded),
                label: const Text('Retirer'),
                style: ElevatedButton.styleFrom(backgroundColor: c.danger, foregroundColor: Colors.white),
              ),
            ),
          if (status == 'removed' || status == 'rejected')
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _busy ? null : () => _act('restore'),
                icon: const Icon(Icons.restore_rounded),
                label: const Text('Rétablir'),
                style: ElevatedButton.styleFrom(backgroundColor: c.primary, foregroundColor: c.onPrimary),
              ),
            ),
        ]),
      ],
    );
  }
}

class _Extra {
  final int reports;
  final List<Map<String, dynamic>> actions;
  _Extra(this.reports, this.actions);
}
