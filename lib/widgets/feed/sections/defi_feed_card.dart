import 'package:afrotok/services/read_meter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/tr.dart';
import '../../../models/model_data.dart';
import '../../../pages/defi/defi_ui.dart';
import '../../../pages/postDetails.dart';
import '../../../providers/authProvider.dart';
import '../../../theme/app_colors.dart';

const Color _orange = Color(0xFFFF9500);
const Color _gold = Color(0xFFFFE14D);

/// Les DÉFIS en cours reviennent souvent dans le fil, comme une publicité : une carte avec la cagnotte, le temps qui reste et un
/// appel à l'action (Participer, ou Voter quand on a déjà participé). Chaque emplacement montre un DÉFI différent, en tournant,
/// pour qu'on n'en perde aucun de vue. Pas de croix : un DÉFI en cours doit rester visible jusqu'à sa fin.
class DefiFeedCard extends StatefulWidget {
  const DefiFeedCard({super.key, required this.slot});

  /// Numéro de l'emplacement dans le fil (0, 1, 2…) : décale le DÉFI affiché.
  final int slot;

  @override
  State<DefiFeedCard> createState() => _DefiFeedCardState();
}

class _DefiFeedCardState extends State<DefiFeedCard> {
  /// Liste partagée par tous les emplacements, relue au plus toutes les 4 minutes.
  static List<Post> _active = const [];
  static DateTime _loadedAt = DateTime.fromMillisecondsSinceEpoch(0);
  static Future<void>? _loading;

  /// DÉFIS déjà montrés pendant cette session : un emplacement préfère un DÉFI encore jamais vu.
  static final Set<String> _seen = {};

  Post? _post;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    if (DateTime.now().difference(_loadedAt) > const Duration(minutes: 4)) {
      _loading ??= _load().whenComplete(() => _loading = null);
      await _loading;
    }
    if (!mounted) return;
    final pick = _pick();
    if (pick != null) _seen.add(pick.id ?? '');
    setState(() => _post = pick);
  }

  static Future<void> _load() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('Posts')
          .where('type', isEqualTo: PostType.DEFI.name)
          .where('defi_config.status', isEqualTo: 'en_cours')
          .limit(40)
          .getM('defi_feed_card.dart:64');
      final now = DateTime.now().millisecondsSinceEpoch;
      final list = <Post>[];
      for (final d in snap.docs) {
        final p = Post.fromJson({...d.data(), 'id': d.id});
        final cfg = p.defiConfig;
        if (cfg == null || cfg.endDate <= now) continue;
        if (p.status != null && p.status != PostStatus.VALIDE.name) continue;
        list.add(p);
      }
      // les plus proches de la fin d'abord : c'est eux qu'il ne faut pas rater
      list.sort((a, b) => a.defiConfig!.endDate.compareTo(b.defiConfig!.endDate));
      _active = list;
      _loadedAt = DateTime.now();
    } catch (e) {
      debugPrint('DefiFeedCard._load : $e');
      _loadedAt = DateTime.now().subtract(const Duration(minutes: 3)); // on réessaiera dans une minute
    }
  }

  Post? _pick() {
    final me = context.read<UserAuthProvider>().loginUserData;
    final now = DateTime.now().millisecondsSinceEpoch;
    final pool = _active.where((p) => p.user_id != me.id && (p.defiConfig?.endDate ?? 0) > now).toList();
    if (pool.isEmpty) return null;
    // ceux où la personne n'a pas encore participé d'abord, puis ceux encore jamais montrés
    pool.sort((a, b) {
      final pa = (a.defiParticipantIds ?? const []).contains(me.id) ? 1 : 0;
      final pb = (b.defiParticipantIds ?? const []).contains(me.id) ? 1 : 0;
      if (pa != pb) return pa - pb;
      final sa = _seen.contains(a.id) ? 1 : 0;
      final sb = _seen.contains(b.id) ? 1 : 0;
      return sa - sb;
    });
    final fresh = pool.where((p) => !_seen.contains(p.id)).toList();
    final base = fresh.isNotEmpty ? fresh : pool;
    return base[widget.slot % base.length];
  }

  String _timeLeft(int endMs) {
    final d = DateTime.fromMillisecondsSinceEpoch(endMs).difference(DateTime.now());
    if (d.isNegative) return context.tr('Terminé');
    if (d.inDays >= 1) return '${d.inDays} j ${d.inHours % 24} h';
    if (d.inHours >= 1) return '${d.inHours} h ${d.inMinutes % 60} min';
    return '${d.inMinutes.clamp(1, 59)} min';
  }

  String? _thumb(Post p) {
    if ((p.thumbnail ?? '').isNotEmpty) return p.thumbnail;
    final imgs = (p.images ?? const <String>[]).where((u) => u.isNotEmpty);
    return imgs.isEmpty ? null : imgs.first;
  }

  void _open(Post p) => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailsPost(post: p)));

  @override
  Widget build(BuildContext context) {
    final p = _post;
    final cfg = p?.defiConfig;
    if (p == null || cfg == null) return const SizedBox.shrink();
    final c = AppColors.of(context);
    final me = context.read<UserAuthProvider>().loginUserData;
    final joined = (p.defiParticipantIds ?? const []).contains(me.id);
    final thumb = _thumb(p);
    final title = (p.description ?? '').trim().isEmpty ? context.tr('Un défi t’attend') : p.description!.trim();
    final people = (p.defiParticipantIds ?? const []).length;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFF9500), Color(0xFFFF5E3A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(2),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.emoji_events_rounded, color: _orange, size: 22),
            const SizedBox(width: 8),
            Expanded(child: Text(context.tr('Défi en cours'), style: TextStyle(color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.w800))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(color: _orange.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.timer_outlined, size: 14, color: _orange),
                const SizedBox(width: 4),
                Text(_timeLeft(cfg.endDate), style: const TextStyle(color: _orange, fontSize: 12, fontWeight: FontWeight.w800)),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => _open(p),
            behavior: HitTestBehavior.opaque,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (thumb != null)
                ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(width: 78, height: 78, child: CachedNetworkImage(imageUrl: thumb, fit: BoxFit.cover))),
              if (thumb != null) const SizedBox(width: 12),
              Expanded(child: Text(title, maxLines: 4, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textPrimary, fontSize: 14, height: 1.35))),
            ]),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 6, children: [
            _chip(context, '🪙 ${cfg.cagnottePieces}', context.tr('cagnotte'), gold: true),
            _chip(context, '$people', context.tr('participants')),
            _chip(context, cfg.participationFee > 0 ? '${cfg.participationFee} 🪙' : context.tr('Gratuit'), context.tr('participation')),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: _orange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
                onPressed: () => joined ? _open(p) : openDefiParticipation(context, p),
                icon: Icon(joined ? Icons.how_to_vote_rounded : Icons.flag_rounded, size: 18),
                label: Text(joined ? context.tr('Voir et voter') : context.tr('Participer'), style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: c.textPrimary, side: BorderSide(color: c.border), padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
              onPressed: () => _open(p),
              child: Text(context.tr('Voir'), style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _chip(BuildContext context, String value, String label, {bool gold = false}) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: (gold ? _gold : c.border).withOpacity(gold ? 0.2 : 0.35), borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(value, style: TextStyle(color: c.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w800)),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: c.textSecondary, fontSize: 11.5)),
      ]),
    );
  }
}
