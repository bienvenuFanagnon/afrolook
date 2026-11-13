import 'package:afrotok/l10n/tr.dart';
import 'package:afrotok/pages/LiveAgora/livePage.dart';
import 'package:afrotok/pages/LiveAgora/live_stage_ui.dart';
import 'package:afrotok/pages/LiveAgora/livesAgora.dart';
import 'package:afrotok/services/api/chat_api.dart';
import 'package:afrotok/services/api/live_stage.dart';
import 'package:afrotok/services/api/live_ticket.dart';
import 'package:afrotok/services/coin_checkout.dart';
import 'package:flutter/material.dart';

/// Ouvre un live en passant d'abord par sa fiche (type, spectateurs, personnes sur scène, essai gratuit et billet), puis l'écran du live.
/// L'hôte n'a pas de fiche : il retrouve directement son live.
Future<void> openLiveWithSheet(BuildContext context, PostLive live, {required bool isHost, required bool isInvited}) {
  if (isHost) return _enter(context, live, isHost: true, isInvited: isInvited, replace: false);
  return Navigator.push(context, MaterialPageRoute(builder: (_) => LiveSheetPage(live: live, isInvited: isInvited)));
}

Future<void> _enter(BuildContext context, PostLive live, {required bool isHost, required bool isInvited, required bool replace}) {
  final route = MaterialPageRoute(
    builder: (_) => LivePage(liveId: live.liveId!, isHost: isHost, hostName: live.hostName ?? '', hostImage: live.hostImage ?? '', isInvited: isInvited, postLive: live),
  );
  return replace ? Navigator.pushReplacement(context, route) : Navigator.push(context, route);
}

/// Fiche d'un live avant d'entrer (maquette 2).
class LiveSheetPage extends StatefulWidget {
  const LiveSheetPage({super.key, required this.live, required this.isInvited});

  final PostLive live;
  final bool isInvited;

  @override
  State<LiveSheetPage> createState() => _LiveSheetPageState();
}

class _LiveSheetPageState extends State<LiveSheetPage> {
  LiveStageState _stage = const LiveStageState();
  LiveTicketOffer? _offer;
  bool _ticketMode = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final id = widget.live.liveId!;
      final results = await Future.wait([LivesApi.stage(id), LivesApi.get(id)]);
      if (!mounted) return;
      setState(() {
        _stage = LiveStageState.fromJson(results[0]);
        _offer = LiveTicketOffer.fromLive(results[1]);
        _ticketMode = _offer != null;
      });
    } catch (_) {}
  }

  static String _typeLabel(String t) => switch (t) {
        'shopping' => 'Vente',
        'duel' => 'Duel',
        'challenge' => 'Défi à plusieurs',
        _ => 'Discussion',
      };

  String _since() {
    final m = DateTime.now().difference(widget.live.startTime).inMinutes;
    return m < 1 ? tr('commencé à l\'instant') : tr('commencé il y a {m} min', {'m': '$m'});
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.live;
    final trial = l.freeTrialMinutes;
    final coins = _offer?.coins ?? 0;
    final offered = l.offerEntry && _ticketMode;
    final cover = (l.coverImage?.isNotEmpty == true) ? l.coverImage! : (l.hostImage ?? '');
    final speakers = [for (final s in _stage.speakers) s.user];
    final label = offered
        ? tr('Regarder, offert par l\'hôte')
        : _ticketMode && trial > 0
            ? tr('Regarder gratuitement ({m} min)', {'m': '$trial'})
            : tr('Regarder');
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: Stack(children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF31503A), Color(0xFF0B0B0B)]),
              image: cover.isNotEmpty ? DecorationImage(image: NetworkImage(cover), fit: BoxFit.cover, onError: (_, __) {}) : null,
            ),
          ),
        ),
        Positioned.fill(child: Container(color: Colors.black.withOpacity(.55))),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 6),
              Row(children: [
                GestureDetector(
                  onTap: () => Navigator.maybePop(context),
                  child: Container(width: 34, height: 34, decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16)),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: const Color(0xFFD92D3A), borderRadius: BorderRadius.circular(8)),
                  child: Text(tr('EN DIRECT'), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: const Color(0xFFFFD400), borderRadius: BorderRadius.circular(8)),
                  child: Text(tr(_typeLabel(l.typeSession)), style: const TextStyle(color: Color(0xFF121212), fontSize: 11, fontWeight: FontWeight.w800)),
                ),
              ]),
              const Spacer(),
              Text(l.title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, height: 1.25)),
              const SizedBox(height: 6),
              Text('${tr('{n} spectateurs', {'n': '${l.viewerCount}'})} · ${_since()}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 4),
              Text('@${l.hostName ?? ''}', style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
              if (speakers.isNotEmpty) ...[
                const SizedBox(height: 14),
                Row(children: [
                  SizedBox(
                    width: 30.0 + (speakers.length.clamp(0, 5) - 1) * 22,
                    height: 30,
                    child: Stack(children: [for (var i = 0; i < speakers.length.clamp(0, 5); i++) Positioned(left: i * 22.0, child: StageAvatar(user: speakers[i], size: 30))]),
                  ),
                  const SizedBox(width: 10),
                  Text(tr('{n} personnes sur scène', {'n': '${speakers.length}'}), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ]),
              ],
              if (_ticketMode && !offered) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(.55), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFF9A825).withOpacity(.5))),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.confirmation_number_rounded, color: Color(0xFFF9A825)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(trial > 0 ? tr('Essai gratuit de {m} minute, puis billet', {'m': '$trial'}) : tr('Billet de {m} minutes', {'m': '${_offer?.minutes ?? 15}'}),
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(
                          trial > 0
                              ? tr('Les minutes gratuites du mois sont épuisées. Après l\'essai : {p} pièces pour {m} minutes.', {'p': CoinCheckout.fmt(coins), 'm': '${_offer?.minutes ?? 15}'})
                              : tr('Les minutes gratuites du mois sont épuisées : {p} pièces pour {m} minutes.', {'p': CoinCheckout.fmt(coins), 'm': '${_offer?.minutes ?? 15}'}),
                          style: const TextStyle(color: Color(0xFFCFCFCA), fontSize: 11.5, height: 1.4),
                        ),
                      ]),
                    ),
                  ]),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => _enter(context, l, isHost: false, isInvited: widget.isInvited, replace: true),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF9A825), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))),
                  child: Text(label, style: const TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 10),
            ]),
          ),
        ),
      ]),
    );
  }
}
