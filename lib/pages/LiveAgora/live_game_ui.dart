import 'dart:async';

import 'package:afrotok/l10n/tr.dart';
import 'package:afrotok/services/api/live_stage.dart';
import 'package:afrotok/services/coin_checkout.dart';
import 'package:flutter/material.dart';

const _amber = Color(0xFFF9A825);
const _yellow = Color(0xFFFFE14D);

/// Jeu en cours lu depuis `GET /lives/{id}/game` : duel, défi à plusieurs, sondage.
class LiveGame {
  LiveGame(this.raw);

  final Map<String, dynamic> raw;

  String get id => '${raw['id']}';
  String get kind => '${raw['kind']}';
  bool get active => raw['status'] == 'active';
  Map get config => raw['config'] is Map ? raw['config'] as Map : const {};
  DateTime? get endsAt => raw['ends_at'] is String ? DateTime.tryParse(raw['ends_at'] as String)?.toLocal() : null;
  int get secondsLeft => (endsAt?.difference(DateTime.now()).inSeconds ?? 0).clamp(0, 86400);
  int get goal => (config['goal'] as num?)?.toInt() ?? 0;
  bool get isMatch => kind == 'duel' || kind == 'challenge';

  List<StageUser> get players => [for (final p in (raw['players'] as List? ?? const [])) if (StageUser.fromJson(p) != null) StageUser.fromJson(p)!];

  int score(String userId) => ((raw['scores'] as Map?)?[userId] as num?)?.toInt() ?? 0;

  String? get winnerId => (raw['result'] as Map?)?['winner_id'] as String?;

  String get question => '${config['question'] ?? ''}';
  List<String> get options => [for (final o in (config['options'] as List? ?? const [])) '$o'];
  List<int> get votes => [for (final v in (raw['votes'] as List? ?? const [])) (v as num).toInt()];
  int? get myVote => (raw['my_vote'] as num?)?.toInt();
}

String clock(int seconds) => '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';

/// Barre de l'objectif du live (« à 5 000 pièces, je chante »), sous les pièces reçues.
class LiveGoalBar extends StatelessWidget {
  const LiveGoalBar({super.key, required this.title, required this.progress, required this.target});

  final String title;
  final int progress;
  final int target;

  @override
  Widget build(BuildContext context) {
    final ratio = target <= 0 ? 0.0 : (progress / target).clamp(0.0, 1.0);
    return Container(
      width: 190,
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 7),
      decoration: BoxDecoration(color: Colors.black.withOpacity(.5), borderRadius: BorderRadius.circular(12), border: Border.all(color: _amber.withOpacity(.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: ratio, minHeight: 6, backgroundColor: Colors.white24, color: ratio >= 1 ? const Color(0xFF69F0AE) : _amber)),
        const SizedBox(height: 3),
        Text('${CoinCheckout.fmt(progress.clamp(0, target))} / ${CoinCheckout.fmt(target)} pcs', style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ]),
    );
  }
}

/// Le jeu à l'écran : duel (deux scores, barre, chrono), défi (une barre par présentateur) ou sondage (choix et pourcentages).
class LiveGameCard extends StatelessWidget {
  const LiveGameCard({super.key, required this.game, required this.target, required this.onTarget, required this.onVote, required this.isHost});

  final LiveGame game;

  /// Présentateur qui recevra les cadeaux (duel et défi).
  final String? target;
  final ValueChanged<String> onTarget;
  final ValueChanged<int> onVote;
  final bool isHost;

  @override
  Widget build(BuildContext context) {
    if (game.kind == 'poll') return _poll(context);
    return _match(context);
  }

  Widget _frame(List<Widget> children) => Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(color: Colors.black.withOpacity(.62), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: children),
      );

  Widget _match(BuildContext context) {
    final ps = game.players;
    final scores = {for (final p in ps) p.id: game.score(p.id)};
    final best = scores.values.fold<int>(0, (a, b) => a > b ? a : b);
    final total = scores.values.fold<int>(0, (a, b) => a + b);
    final isDuel = game.kind == 'duel';
    final ended = !game.active;
    final w = game.winnerId;
    return _frame([
      Row(children: [
        Text(isDuel ? context.tr('Duel') : context.tr('Défi à plusieurs'), style: const TextStyle(color: _yellow, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .6)),
        const Spacer(),
        if (game.active && game.endsAt != null) _Countdown(game: game),
        if (ended) Text(w == null ? context.tr('Égalité') : '🏆 @${ps.where((p) => p.id == w).map((p) => p.username).firstOrNull ?? ''}', style: const TextStyle(color: Color(0xFF69F0AE), fontSize: 12, fontWeight: FontWeight.w800)),
      ]),
      if (!isDuel && game.goal > 0) Padding(padding: const EdgeInsets.only(top: 2), child: Text(context.tr('Le premier à {n} pièces gagne', {'n': CoinCheckout.fmt(game.goal)}), style: const TextStyle(color: Colors.white70, fontSize: 11.5))),
      const SizedBox(height: 8),
      if (isDuel && ps.length == 2) ...[
        Row(children: [
          Expanded(child: _name(ps[0], scores[ps[0].id]! == best && best > 0 && game.active)),
          Text('VS', style: TextStyle(color: Colors.white.withOpacity(.6), fontWeight: FontWeight.w900)),
          Expanded(child: _name(ps[1], scores[ps[1].id]! == best && best > 0 && game.active, right: true)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: SizedBox(
            height: 10,
            child: Row(children: [
              Expanded(flex: total == 0 ? 1 : scores[ps[0].id]!.clamp(1, 1 << 30), child: Container(color: _amber)),
              Expanded(flex: total == 0 ? 1 : scores[ps[1].id]!.clamp(1, 1 << 30), child: Container(color: const Color(0xFF5B9CFA))),
            ]),
          ),
        ),
        const SizedBox(height: 4),
        Row(children: [
          Text('${CoinCheckout.fmt(scores[ps[0].id]!)} pcs', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
          const Spacer(),
          Text('${CoinCheckout.fmt(scores[ps[1].id]!)} pcs', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
        ]),
      ] else
        for (final p in ps) ...[
          Row(children: [
            StageAvatarMini(user: p),
            const SizedBox(width: 6),
            Expanded(child: Text('@${p.username}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
            Text(game.goal > 0 ? '${CoinCheckout.fmt(scores[p.id]!)} / ${CoinCheckout.fmt(game.goal)} pcs' : '${CoinCheckout.fmt(scores[p.id]!)} pcs', style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ]),
          const SizedBox(height: 3),
          ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: game.goal > 0 ? (scores[p.id]! / game.goal).clamp(0.0, 1.0) : (best == 0 ? 0 : scores[p.id]! / best), minHeight: 7, backgroundColor: Colors.white24, color: scores[p.id] == best && best > 0 ? _amber : const Color(0xFF5B9CFA))),
          const SizedBox(height: 7),
        ],
      if (game.active) ...[
        const SizedBox(height: 4),
        Text(context.tr('Les cadeaux envoyés à un présentateur font avancer sa barre.'), style: const TextStyle(color: Colors.white54, fontSize: 10.5)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 4, children: [
          for (final p in ps)
            GestureDetector(
              onTap: () => onTarget(p.id),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: target == p.id ? _amber : Colors.white12, borderRadius: BorderRadius.circular(14)),
                child: Text('→ @${p.username}', style: TextStyle(color: target == p.id ? Colors.black : Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ),
        ]),
      ],
    ]);
  }

  Widget _name(StageUser p, bool lead, {bool right = false}) => Column(crossAxisAlignment: right ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
        Text('@${p.username}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800)),
        if (lead) Text('EN TÊTE', style: TextStyle(color: const Color(0xFF69F0AE).withOpacity(.9), fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: .6)),
      ]);

  Widget _poll(BuildContext context) {
    final votes = game.votes;
    final total = votes.fold<int>(0, (a, b) => a + b);
    final mine = game.myVote;
    final open = game.active && mine == null;
    return _frame([
      Row(children: [
        Text(context.tr('Sondage'), style: const TextStyle(color: _yellow, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .6)),
        const Spacer(),
        if (game.active && game.endsAt != null) _Countdown(game: game),
      ]),
      const SizedBox(height: 4),
      Text(game.question, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      for (var i = 0; i < game.options.length; i++) ...[
        GestureDetector(
          onTap: open && !isHost ? () => onVote(i) : null,
          child: Container(
            height: 36,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: mine == i ? _amber : Colors.white24, width: mine == i ? 2 : 1)),
            child: Stack(children: [
              Positioned.fill(
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: total == 0 ? 0.0 : (i < votes.length ? votes[i] / total : 0.0).clamp(0.0, 1.0).toDouble(),
                  child: Container(decoration: BoxDecoration(color: _amber.withOpacity(.28), borderRadius: BorderRadius.circular(9))),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(children: [
                  Expanded(child: Text(game.options[i], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))),
                  if (!open || isHost) Text(total == 0 ? '0 %' : '${((i < votes.length ? votes[i] : 0) * 100 / total).round()} %', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
                ]),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 6),
      ],
      Text(context.tr('{n} votes', {'n': '$total'}), style: const TextStyle(color: Colors.white54, fontSize: 10.5)),
    ]);
  }
}

class StageAvatarMini extends StatelessWidget {
  const StageAvatarMini({super.key, required this.user});

  final StageUser user;

  @override
  Widget build(BuildContext context) {
    final url = user.avatarUrl;
    return CircleAvatar(radius: 10, backgroundColor: Colors.white24, backgroundImage: url != null && url.isNotEmpty ? NetworkImage(url) : null, onBackgroundImageError: url != null && url.isNotEmpty ? (_, __) {} : null,
        child: url != null && url.isNotEmpty ? null : Text(user.initials.substring(0, 1), style: const TextStyle(fontSize: 9, color: Colors.white)));
  }
}

class _Countdown extends StatefulWidget {
  const _Countdown({required this.game});

  final LiveGame game;

  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: widget.game.secondsLeft < 30 ? Colors.red.withOpacity(.85) : Colors.black54, borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.timer_rounded, color: Colors.white, size: 11),
          const SizedBox(width: 3),
          Text(clock(widget.game.secondsLeft), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
        ]),
      );
}

/// Menu « Jeux » de l'hôte : objectif, duel, défi, sondage, tirage au sort, questions du public.
Future<String?> showGamesMenu(BuildContext context, {required bool hasStageGuests, required bool gameActive}) {
  Widget item(BuildContext ctx, String key, IconData icon, String title, String sub, {bool enabled = true}) => Opacity(
        opacity: enabled ? 1 : .45,
        child: ListTile(
          leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: _amber.withOpacity(.15), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: _amber)),
          title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          subtitle: Text(sub, style: const TextStyle(color: Color(0xFF9A9A95), fontSize: 12)),
          onTap: enabled ? () => Navigator.pop(ctx, key) : null,
        ),
      );
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: const Color(0xFF1A1A1A),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFF4A4A46), borderRadius: BorderRadius.circular(2))),
          Padding(padding: const EdgeInsets.all(14), child: Text(ctx.tr('Jeux du live'), style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700))),
          item(ctx, 'goal', Icons.flag_rounded, ctx.tr('Objectif du live'), ctx.tr('Une barre qui monte avec les cadeaux')),
          item(ctx, 'duel', Icons.sports_mma_rounded, ctx.tr('Duel 1 contre 1'), hasStageGuests ? ctx.tr('5 minutes, les cadeaux décident') : ctx.tr('Invite d\'abord quelqu\'un sur scène'), enabled: hasStageGuests),
          item(ctx, 'challenge', Icons.groups_rounded, ctx.tr('Défi à plusieurs'), hasStageGuests ? ctx.tr('Le premier à l\'objectif gagne') : ctx.tr('Invite d\'abord des présentateurs sur scène'), enabled: hasStageGuests),
          item(ctx, 'poll', Icons.poll_rounded, ctx.tr('Sondage'), ctx.tr('Le public vote en direct')),
          item(ctx, 'questions', Icons.help_outline_rounded, ctx.tr('Questions du public'), ctx.tr('Lis et épingle une question')),
          item(ctx, 'draw', Icons.card_giftcard_rounded, ctx.tr('Tirage au sort'), ctx.tr('Mets des pièces en jeu')),
          if (gameActive) item(ctx, 'end', Icons.stop_circle_rounded, ctx.tr('Arrêter le jeu en cours'), ''),
          const SizedBox(height: 12),
        ]),
      ),
    ),
  );
}

/// Petit formulaire de texte et de nombre en fenêtre (objectif, tirage, sondage).
Future<List<String>?> askFields(BuildContext context, {required String title, required List<({String label, String hint, bool number, String initial})> fields, String ok = 'Valider'}) {
  final ctrls = [for (final f in fields) TextEditingController(text: f.initial)];
  return showDialog<List<String>>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < fields.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(controller: ctrls[i], keyboardType: fields[i].number ? TextInputType.number : TextInputType.text, decoration: InputDecoration(labelText: fields[i].label, hintText: fields[i].hint)),
            ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.tr('Annuler'))),
        FilledButton(onPressed: () => Navigator.pop(ctx, [for (final c in ctrls) c.text.trim()]), child: Text(ctx.tr(ok))),
      ],
    ),
  );
}
