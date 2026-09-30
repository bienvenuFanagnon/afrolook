import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../l10n/tr.dart';
import '../../services/coin_checkout.dart';
import '../../theme/app_colors.dart';
import 'studio/new_pack_wizard.dart';

/// « Studio créateur » : gains du mois, mes packs et dépôt d'un nouveau pack.
class StickerStudioPage extends StatefulWidget {
  const StickerStudioPage({super.key});

  @override
  State<StickerStudioPage> createState() => _StickerStudioPageState();
}

class _StickerStudioPageState extends State<StickerStudioPage> {
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  bool _loading = true;
  bool _error = false;
  int _monthCoins = 0;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _packs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = _uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final db = FirebaseFirestore.instance;
      final res = await Future.wait([
        db.collection('TransactionSoldes').where('user_id', isEqualTo: uid).limit(300).get(),
        db.collection('StickerPacks').where('creatorId', isEqualTo: uid).get(),
      ]);
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, 1).millisecondsSinceEpoch;
      var sum = 0.0;
      for (final d in res[0].docs) {
        final m = d.data();
        final kind = m['purchaseKind'];
        if (m['type'] != 'GAIN_PIECES' || (kind != 'sticker_pack' && kind != 'sticker_gift')) continue;
        var created = (m['createdAt'] as num?)?.toInt() ?? 0;
        if (created > 100000000000000) created ~/= 1000;
        if (created < start) continue;
        sum += (m['montant'] as num?)?.toDouble() ?? 0;
      }
      final packs = res[1].docs.toList()
        ..sort((a, b) => ((b.data()['createdAt'] as num?) ?? 0).compareTo((a.data()['createdAt'] as num?) ?? 0));
      if (!mounted) return;
      setState(() {
        _monthCoins = sum.round();
        _packs = packs;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  Future<void> _newPack() async {
    final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const NewPackWizard()));
    if (ok == true) _load();
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
        title: Text(context.tr('Studio créateur'), style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                children: [
                  _earningsCard(c),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _newPack,
                      icon: const Icon(Icons.add_rounded),
                      label: Text(context.tr('Déposer un pack'), style: const TextStyle(fontWeight: FontWeight.w800)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.primary,
                        foregroundColor: c.onPrimary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(context.tr('Mes packs'),
                      style: TextStyle(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  if (_error)
                    Text(context.tr('Chargement impossible, tire pour réessayer'), style: TextStyle(color: c.danger))
                  else if (_packs.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(context.tr('Tu n\'as pas encore déposé de pack'), style: TextStyle(color: c.textSecondary)),
                    )
                  else
                    for (final p in _packs) _packTile(c, p.data(), p.id),
                  const SizedBox(height: 20),
                  _rules(c),
                ],
              ),
            ),
    );
  }

  Widget _earningsCard(AppColors c) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(context.tr('Gagné ce mois avec tes stickers'),
            style: TextStyle(color: c.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(context.tr('{n} pièces', {'n': CoinCheckout.fmt(_monthCoins)}),
            style: TextStyle(color: c.primary, fontSize: 28, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(context.tr('70 % du prix des packs vendus pour toi, 30 % pour Afrolook'),
            style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
      ]),
    );
  }

  Future<void> _editPrice(String packId, int current) async {
    final ctrl = TextEditingController(text: current.toString());
    final value = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Modifier le prix')),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(context.tr('Prix du pack en pièces (0 = gratuit, 1000 maximum)')),
          const SizedBox(height: 10),
          TextField(controller: ctrl, keyboardType: TextInputType.number, autofocus: true),
          const SizedBox(height: 10),
          Text(
            context.tr('Un pack gratuit peut devenir payant : les nouveaux utilisateurs devront l\'acheter, ceux qui l\'ont déjà acheté le gardent. Tu peux changer le prix une fois tous les 7 jours.'),
            style: const TextStyle(fontSize: 12.5),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('Annuler'))),
          FilledButton(
            onPressed: () {
              final v = int.tryParse(ctrl.text.trim());
              if (v != null && v >= 0 && v <= 1000) Navigator.pop(ctx, v);
            },
            child: Text(context.tr('Enregistrer')),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (value == null || value == current) return;
    try {
      await FirebaseFunctions.instance.httpsCallable('updateStickerPackPrice').call({'packId': packId, 'priceCoins': value});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Prix modifié'))));
      _load();
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? context.tr('Le prix n\'a pas pu être modifié.'))));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Le prix n\'a pas pu être modifié.'))));
    }
  }

  Widget _packTile(AppColors c, Map<String, dynamic> p, String packId) {
    final status = (p['status'] ?? '').toString();
    final needsReview = p['needsReview'] == true;
    String label;
    Color color;
    switch (status) {
      case 'active':
        label = context.tr('Publié');
        color = c.success;
        break;
      case 'pending':
        label = needsReview ? context.tr('Vérification') : context.tr('En validation');
        color = c.warning;
        break;
      case 'rejected':
        label = context.tr('Refusé');
        color = c.danger;
        break;
      default:
        label = context.tr('Retiré');
        color = c.textSecondary;
    }
    final price = (p['priceCoins'] as num?)?.toInt() ?? 0;
    final count = (p['stickerCount'] as num?)?.toInt() ?? 0;
    final sales = (p['salesCount'] as num?)?.toInt() ?? 0;
    final reason = (p['rejectReason'] ?? '').toString();
    final cover = (p['coverUrl'] ?? '').toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 56,
            height: 56,
            color: c.surfaceVariant,
            child: cover.isEmpty
                ? Icon(Icons.emoji_emotions_outlined, color: c.textSecondary)
                : Image.network(cover, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.image_not_supported_outlined, color: c.textSecondary)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text((p['name'] ?? '').toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 14.5)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(8)),
                child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 4),
            Text(
              '${context.tr('{n} stickers', {'n': count})} · '
              '${price == 0 ? context.tr('Gratuit') : context.tr('{n} pièces', {'n': CoinCheckout.fmt(price)})} · '
              '${context.tr('{n} ventes', {'n': sales})}',
              style: TextStyle(color: c.textSecondary, fontSize: 12),
            ),
            if (status == 'active' || status == 'pending')
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 30), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  onPressed: () => _editPrice(packId, price),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: Text(context.tr('Modifier le prix'), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                ),
              ),
            if (status == 'rejected' && reason.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(context.tr('Motif : {r}', {'r': reason}), style: TextStyle(color: c.danger, fontSize: 12)),
              ),
          ]),
        ),
      ]),
    );
  }

  Widget _rules(AppColors c) {
    Widget line(String t) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('•  ', style: TextStyle(color: c.textSecondary)),
            Expanded(child: Text(t, style: TextStyle(color: c.textSecondary, fontSize: 12.5, height: 1.3))),
          ]),
        );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.surfaceVariant, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(context.tr('Règles du studio'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        line(context.tr('Ne dépose que des stickers dont tu détiens tous les droits.')),
        line(context.tr('Contenus interdits : violence, nudité, haine, contrefaçon et copies de stickers d\'autres créateurs.')),
        line(context.tr('Chaque pack est vérifié avant publication et peut être retiré en cas de non-respect des règles.')),
        line(context.tr('Gains : 70 % du prix de chaque pack vendu, en pièces gagnées. Un sticker-cadeau te rapporte 30 % de son prix.')),
        line(context.tr('Il faut un abonnement Premium ou Gold et un compte de plus de 30 jours. 3 packs en attente maximum.')),
      ]),
    );
  }
}
