import 'package:afrolook_api_client/afrolook_api_client.dart' show ApiException;
import 'package:afrotok/l10n/tr.dart';
import 'package:afrotok/services/api/api_identity.dart';
import 'package:afrotok/services/api/chat_api.dart';
import 'package:afrotok/services/api/users_api.dart';
import 'package:afrotok/services/coin_checkout.dart';
import 'package:flutter/material.dart';

const _amber = Color(0xFFF9A825);

/// Clips d'un live (idée 5). L'hôte voit les clips proposés et retient ceux qu'il aime : la prime est versée tout de suite.
/// Les autres voient les clips retenus et les leurs, et proposent une de leurs publications tant que l'hôte a ouvert les clips.
class LiveClipsPage extends StatefulWidget {
  const LiveClipsPage({super.key, required this.liveId});

  final String liveId;

  @override
  State<LiveClipsPage> createState() => _LiveClipsPageState();
}

class _LiveClipsPageState extends State<LiveClipsPage> {
  Map<String, dynamic>? _d;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await LivesApi.clips(widget.liveId);
      if (mounted) setState(() => _d = d);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  static String? _thumb(Map? post) => post?['thumbnail_url'] as String?;

  Future<void> _decide(Map c, bool retain) async {
    try {
      await LivesApi.clipDecide(widget.liveId, '${c['id']}', retain: retain);
    } on ApiException catch (e) {
      if (mounted) {
        if (e.isInsufficientCoins) {
          await CoinCheckout.insufficient(context, (_d?['bounty_coins'] as num?)?.toInt() ?? 0);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
        }
      }
    } catch (_) {}
    await _load();
  }

  /// Le clippeur choisit une de ses publications récentes.
  Future<void> _propose() async {
    final me = ApiIdentity.myId;
    if (me == null) return;
    List<Map<String, dynamic>> posts = const [];
    try {
      posts = (await UsersApi.userPosts(me, limit: 30)).items;
    } catch (_) {}
    if (!mounted) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * .6,
          child: Column(children: [
            Padding(padding: const EdgeInsets.all(14), child: Text(ctx.tr('Quelle publication proposer ?'), style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700))),
            Expanded(
              child: posts.isEmpty
                  ? Center(child: Text(ctx.tr('Aucune publication récente.'), style: const TextStyle(color: Colors.white70)))
                  : GridView.count(
                      crossAxisCount: 3,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      childAspectRatio: .7,
                      children: [
                        for (final p in posts)
                          GestureDetector(
                            onTap: () => Navigator.pop(ctx, '${p['id']}'),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                color: Colors.white12,
                                child: (() {
                                  final m = (p['media'] as List?)?.whereType<Map>().firstOrNull;
                                  final u = (m?['thumbnail_url'] ?? m?['url']) as String?;
                                  return u == null ? const Icon(Icons.movie_rounded, color: Colors.white38) : Image.network(u, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.movie_rounded, color: Colors.white38));
                                })(),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ]),
        ),
      ),
    );
    if (picked == null) return;
    try {
      await LivesApi.clipSubmit(widget.liveId, picked);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Clip proposé à l\'hôte.'))));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {}
    await _load();
  }

  Widget _row(Map c, bool host) {
    final p = c['post'] as Map?;
    final u = c['user'] as Map?;
    final status = '${c['status']}';
    final t = _thumb(p);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFF242424), borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(width: 64, height: 92, color: Colors.white12, child: t == null ? const Icon(Icons.movie_rounded, color: Colors.white38) : Image.network(t, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.movie_rounded, color: Colors.white38))),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${p?['description'] ?? context.tr('Clip')}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
            Text('${context.tr('par')} @${u?['username'] ?? ''} · ${p?['views'] ?? 0} ${context.tr('vues')}', style: const TextStyle(color: Color(0xFF9A9A95), fontSize: 11)),
            const SizedBox(height: 8),
            if (status == 'pending' && host)
              Row(children: [
                GestureDetector(
                  onTap: () => _decide(c, true),
                  child: Container(height: 30, padding: const EdgeInsets.symmetric(horizontal: 12), alignment: Alignment.center, decoration: BoxDecoration(color: _amber, borderRadius: BorderRadius.circular(15)),
                      child: Text('${context.tr('Retenir')} · ${_d?['bounty_coins']} pcs', style: const TextStyle(color: Colors.black, fontSize: 11.5, fontWeight: FontWeight.w800))),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _decide(c, false),
                  child: Container(height: 30, padding: const EdgeInsets.symmetric(horizontal: 12), alignment: Alignment.center, decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFF4A4A46))),
                      child: Text(context.tr('Écarter'), style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700))),
                ),
              ])
            else
              Text(status == 'retained' ? '+${c['coins']} pcs' : status == 'rejected' ? context.tr('Écarté') : context.tr('En attente'),
                  style: TextStyle(color: status == 'retained' ? const Color(0xFF2ECC71) : const Color(0xFF9A9A95), fontSize: 12, fontWeight: FontWeight.w800)),
          ]),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    final host = d?['is_host'] == true;
    final clips = [for (final c in (d?['clips'] as List? ?? const [])) c as Map];
    final pending = clips.where((c) => c['status'] == 'pending').toList();
    final others = clips.where((c) => c['status'] != 'pending').toList();
    final bounty = (d?['bounty_coins'] as num?)?.toInt() ?? 0;
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(backgroundColor: const Color(0xFF121212), foregroundColor: Colors.white, elevation: 0, title: Text(context.tr('Clips du live'), style: const TextStyle(fontWeight: FontWeight.w800))),
      body: d == null
          ? Center(child: _failed ? Text(context.tr('Chargement impossible.'), style: const TextStyle(color: Colors.white70)) : const CircularProgressIndicator(color: _amber))
          : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: const Color(0xFF2A2312), border: Border.all(color: _amber.withOpacity(.5)), borderRadius: BorderRadius.circular(16)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(bounty > 0 ? context.tr('Prime par clip retenu : {n} pièces', {'n': CoinCheckout.fmt(bounty)}) : context.tr('Les clips ne sont pas ouverts pour ce live.'), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(
                    host
                        ? context.tr('Tes spectateurs proposent les meilleurs moments (15 à 60 secondes). Tu retiens ceux que tu aimes : la prime est versée par tes pièces.')
                        : context.tr('Publie un extrait de ce live puis propose-le ici : si l\'hôte le retient, tu reçois la prime.'),
                    style: const TextStyle(color: Color(0xFFCFCFCA), fontSize: 12, height: 1.4),
                  ),
                  if (host) ...[
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, children: [
                      _pill('${clips.length} ${context.tr('clips proposés')}'),
                      _pill('${d['retained']} ${context.tr('retenus')}', const Color(0xFF2ECC71), const Color(0xFF0E0E0E)),
                      _pill('${d['paid_coins']} pcs ${context.tr('versées')}'),
                    ]),
                  ],
                ]),
              ),
              if (!host && bounty > 0) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    onPressed: _propose,
                    style: ElevatedButton.styleFrom(backgroundColor: _amber, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23))),
                    child: Text(context.tr('Proposer un de mes clips'), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
              if (pending.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text('${context.tr(host ? 'À valider' : 'En attente')} · ${pending.length}'.toUpperCase(), style: const TextStyle(color: _amber, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .6)),
                const SizedBox(height: 6),
                for (final c in pending) _row(c, host),
              ],
              if (others.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(context.tr('Retenus et traités').toUpperCase(), style: const TextStyle(color: _amber, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .6)),
                const SizedBox(height: 6),
                for (final c in others) _row(c, host),
              ],
              const SizedBox(height: 12),
              Text(context.tr('Un clip est une publication normale du clippeur, avec les mêmes contrôles d\'authenticité. On ne peut pas retenir ses propres clips.'), style: const TextStyle(color: Color(0xFF9A9A95), fontSize: 11.5, height: 1.4)),
            ]),
    );
  }

  Widget _pill(String t, [Color bg = const Color(0x1FFFFFFF), Color fg = Colors.white]) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Text(t, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w800)),
      );
}
