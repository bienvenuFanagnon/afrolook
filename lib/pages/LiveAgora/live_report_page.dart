import 'package:afrotok/l10n/tr.dart';
import 'package:afrotok/services/api/chat_api.dart';
import 'package:afrotok/services/coin_checkout.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

/// Bilan du live (maquette 15) : ce que l'hôte a gagné, les chiffres, les plus généreux, ce que les spectateurs ont payé.
/// Jamais la part gardée par Afrolook.
class LiveReportPage extends StatefulWidget {
  const LiveReportPage({super.key, required this.liveId, this.fallbackCoins = 0, this.fallbackTitle = ''});

  final String liveId;

  /// Chiffres connus de l'écran du live, affichés si le bilan du serveur n'arrive pas.
  final int fallbackCoins;
  final String fallbackTitle;

  @override
  State<LiveReportPage> createState() => _LiveReportPageState();
}

class _LiveReportPageState extends State<LiveReportPage> {
  Map<String, dynamic>? _r;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await LivesApi.report(widget.liveId);
      if (mounted) setState(() => _r = r);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  int _i(String k) => (_r?[k] as num?)?.toInt() ?? 0;

  String _duration() {
    final m = _i('duration_minutes');
    return m >= 60 ? '${m ~/ 60} h ${(m % 60).toString().padLeft(2, '0')}' : '$m min';
  }

  static const _months = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];

  String _date() {
    final d = DateTime.tryParse('${_r?['started_at']}')?.toLocal();
    return d == null ? '' : '${d.day} ${tr(_months[d.month - 1])}';
  }

  static String _type(String t) => switch (t) {
        'shopping' => 'Vente',
        'duel' => 'Duel',
        'challenge' => 'Défi à plusieurs',
        _ => 'Discussion',
      };

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF121212);
    final r = _r;
    final gifts = r != null ? _i('gifts_coins') : widget.fallbackCoins;
    final extra = _i('ticket_extra_coins');
    final total = gifts + extra;
    final title = r?['title'] as String? ?? widget.fallbackTitle;
    Widget stat(String label, String value) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(color: Color(0xFF9A9A95), fontSize: 11.5)),
              const SizedBox(height: 3),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            ]),
          ),
        );
    Widget line(String a, String b) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(a, style: const TextStyle(color: Color(0xFFCFCFCA), fontSize: 13.5)),
            Text(b, style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700)),
          ]),
        );
    final donors = (r?['top_donors'] as List?) ?? const [];
    final medals = ['🥇', '🥈', '🥉'];
    final tickets = _i('paid_tickets');
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: r == null && !_failed
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFF9A825)))
            : ListView(padding: const EdgeInsets.fromLTRB(18, 16, 18, 24), children: [
                Row(children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF69F0AE), size: 22),
                  const SizedBox(width: 8),
                  Text(tr('Ce live est terminé'), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 8),
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                if (r != null) Text('${tr(_type('${r['type_session']}'))} · ${_duration()} · ${_date()}', style: const TextStyle(color: Color(0xFF9A9A95), fontSize: 12.5)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFF2A2312), border: Border.all(color: const Color(0xFFF9A825).withOpacity(.5)), borderRadius: BorderRadius.circular(16)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tr('Tu as gagné'), style: const TextStyle(color: Color(0xFFCFCFCA), fontSize: 13)),
                    const SizedBox(height: 2),
                    Text('${CoinCheckout.fmt(total)} pcs', style: const TextStyle(color: Color(0xFFF9A825), fontSize: 30, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    line(tr('Cadeaux reçus'), CoinCheckout.fmt(gifts)),
                    if (r != null && (r['ticket_mode'] == true || extra > 0)) line(tr('Supplément des billets'), CoinCheckout.fmt(extra)),
                    if (r != null && _i('sales_xof') > 0) line(tr('Ventes (commandes validées)'), '${CoinCheckout.fmt(_i('sales_xof'))} F'),
                  ]),
                ),
                if (r != null) ...[
                  const SizedBox(height: 12),
                  Row(children: [stat(tr('Spectateurs'), CoinCheckout.fmt(_i('viewers'))), const SizedBox(width: 10), stat(tr('Pic en même temps'), CoinCheckout.fmt(_i('peak_viewers')))]),
                  const SizedBox(height: 10),
                  Row(children: [stat(tr('Durée'), _duration()), const SizedBox(width: 10), stat(tr('J\'aime'), CoinCheckout.fmt(_i('likes')))]),
                  const SizedBox(height: 10),
                  Row(children: [stat(tr('Partages'), CoinCheckout.fmt(_i('shares'))), const SizedBox(width: 10), stat(tr('Invités sur scène'), CoinCheckout.fmt(_i('stage_guests')))]),
                ],
                if (donors.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(tr('Les plus généreux'), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  for (var i = 0; i < donors.length && i < 3; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        Text(medals[i], style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 10),
                        Expanded(child: Text('${(donors[i] as Map)['username']}', style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w600))),
                        Text('${(donors[i] as Map)['coins']} pcs', style: const TextStyle(color: Color(0xFFF9A825), fontSize: 13, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                ],
                if (r != null) ...[
                  const SizedBox(height: 14),
                  Text.rich(TextSpan(children: [
                    TextSpan(text: '${tr('Entrées et billets payés par tes spectateurs :')} '),
                    TextSpan(text: '$tickets', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    TextSpan(text: r['ticket_mode'] == true ? '.' : '. ${tr('Les minutes de ce live étaient')} '),
                    if (r['ticket_mode'] != true) TextSpan(text: tr('gratuites'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    if (r['ticket_mode'] != true) const TextSpan(text: '.'),
                  ]), style: const TextStyle(color: Color(0xFF9A9A95), fontSize: 12.5, height: 1.45)),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () => Share.share(tr('Mon live « {t} » sur Afrolook : {v} spectateurs, {c} pièces reçues.', {'t': title, 'v': '${_i('viewers')}', 'c': CoinCheckout.fmt(total)})),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white30), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))),
                    child: Text(tr('Partager un résumé'), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF9A825), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))),
                    child: Text(tr('Retour aux lives'), style: const TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
      ),
    );
  }
}
