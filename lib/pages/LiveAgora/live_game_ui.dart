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

  /// Les meilleurs donateurs d'un présentateur pendant ce jeu (jusqu'à trois), du plus généreux au moins généreux.
  List<({String username, int coins})> topGiversOf(String userId) {
    final l = (raw['top_givers'] as Map?)?[userId];
    if (l is! List) return const [];
    return [for (final g in l) if (g is Map) (username: '${g['username'] ?? ''}', coins: (g['coins'] as num?)?.toInt() ?? 0)];
  }

  /// Ce qu'un présentateur a reçu pendant le jeu : nombre de cadeaux, pièces envoyées, et sa part (70 %) versée sur SON compte (pièces gagnées).
  ({int gifts, int coins, int earned}) earnedOf(String userId) {
    final e = (raw['earned'] as Map?)?[userId];
    if (e is! Map) return (gifts: 0, coins: 0, earned: 0);
    return (gifts: (e['gifts'] as num?)?.toInt() ?? 0, coins: (e['coins'] as num?)?.toInt() ?? 0, earned: (e['earned'] as num?)?.toInt() ?? 0);
  }

  String get question => '${config['question'] ?? ''}';
  List<String> get options => [for (final o in (config['options'] as List? ?? const [])) '$o'];
  List<int> get votes => [for (final v in (raw['votes'] as List? ?? const [])) (v as num).toInt()];
  int? get myVote => (raw['my_vote'] as num?)?.toInt();

  // conte interactif : voix en pièces par choix
  int get myCoins => (raw['my_coins'] as num?)?.toInt() ?? 0;
  int get voteCoins => (raw['vote_coins'] as num?)?.toInt() ?? 10;
  int? get winnerOption => (raw['winner_option'] as num?)?.toInt();

  // quiz à cagnotte : question en cours, classement
  Map get quiz => raw['quiz'] is Map ? raw['quiz'] as Map : const {};
  List get winners => raw['winners'] is List ? raw['winners'] as List : const [];
}

/// Une question de quiz saisie par l'hôte : `Question ? | choix A | choix B* | choix C` (l'étoile marque la bonne réponse).
class QuizDraft {
  QuizDraft(this.text, this.options, this.correct);

  final String text;
  final List<String> options;
  final int correct;

  Map<String, dynamic> toJson() => {'text': text, 'options': options, 'correct': correct};

  /// Lit le texte saisi, une question par ligne ; renvoie `null` si une ligne est incomplète (moins de 2 choix, pas de bonne réponse).
  static List<QuizDraft>? parse(String input) {
    final out = <QuizDraft>[];
    for (final line in input.split('\n')) {
      if (line.trim().isEmpty) continue;
      final parts = line.split('|').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      if (parts.length < 3 || parts.length > 5) return null;
      final opts = <String>[];
      var correct = -1;
      for (final raw in parts.skip(1)) {
        final star = raw.endsWith('*');
        final t = star ? raw.substring(0, raw.length - 1).trim() : raw;
        if (t.isEmpty) return null;
        if (star) {
          if (correct != -1) return null;
          correct = opts.length;
        }
        opts.add(t);
      }
      if (correct == -1) return null;
      out.add(QuizDraft(parts.first, opts, correct));
    }
    return out.isEmpty || out.length > 10 ? null : out;
  }
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
  const LiveGameCard({super.key, required this.game, required this.target, required this.onTarget, required this.onVote, required this.isHost, this.onStoryVote, this.onAnswer});

  final LiveGame game;

  /// Présentateur qui recevra les cadeaux (duel et défi).
  final String? target;
  final ValueChanged<String> onTarget;
  final ValueChanged<int> onVote;
  final bool isHost;

  /// Conte : vote payant (10 pièces). Quiz : réponse à la question en cours.
  final ValueChanged<int>? onStoryVote;
  final ValueChanged<int>? onAnswer;

  @override
  Widget build(BuildContext context) {
    if (game.kind == 'poll') return _poll(context);
    if (game.kind == 'story') return _story(context);
    if (game.kind == 'quiz') return _quiz(context);
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
        if (ps.any((p) => game.topGiversOf(p.id).isNotEmpty)) ...[
          const SizedBox(height: 6),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _givers(context, ps[0].id)),
            const SizedBox(width: 10),
            Expanded(child: _givers(context, ps[1].id, right: true)),
          ]),
        ],
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
          if (game.topGiversOf(p.id).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: _givers(context, p.id, inline: true)),
          const SizedBox(height: 7),
        ],
      if (ended) ...[
        const SizedBox(height: 4),
        for (final p in ps)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text('@${p.username} : ${game.earnedOf(p.id).gifts} ${context.tr('cadeaux')} · +${CoinCheckout.fmt(game.earnedOf(p.id).earned)} ${context.tr('pièces sur son compte')}', style: const TextStyle(color: Color(0xFFFFD27A), fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        const SizedBox(height: 4),
        Text(context.tr('Pas de lot en plus pour le gagnant : chacun garde les cadeaux reçus (70 %).'), style: const TextStyle(color: Colors.white38, fontSize: 10)),
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

  /// Meilleurs donateurs d'un présentateur : 🥇 🥈 🥉, pseudo et pièces données.
  Widget _givers(BuildContext context, String userId, {bool right = false, bool inline = false}) {
    const medals = ['🥇', '🥈', '🥉'];
    final top = game.topGiversOf(userId);
    if (top.isEmpty) return const SizedBox.shrink();
    final lines = [for (var i = 0; i < top.length && i < 3; i++) '${medals[i]} @${top[i].username} ${CoinCheckout.fmt(top[i].coins)}'];
    const st = TextStyle(color: Color(0xFFFFD27A), fontSize: 10.5, fontWeight: FontWeight.w700);
    if (inline) return Text(lines.join('  '), maxLines: 1, overflow: TextOverflow.ellipsis, style: st);
    return Column(crossAxisAlignment: right ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [for (final l in lines) Text(l, maxLines: 1, overflow: TextOverflow.ellipsis, style: st)]);
  }

  Widget _name(StageUser p, bool lead, {bool right = false}) => Column(crossAxisAlignment: right ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
        Text('@${p.username}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800)),
        if (lead) Text('EN TÊTE', style: TextStyle(color: const Color(0xFF69F0AE).withOpacity(.9), fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: .6)),
      ]);

  /// Conte interactif : le public vote avec des pièces, l'option la plus soutenue décide de la suite.
  Widget _story(BuildContext context) {
    final votes = game.votes;
    final total = votes.fold<int>(0, (a, b) => a + b);
    final done = !game.active;
    return _frame([
      Row(children: [
        Text(context.tr('La suite de l\'histoire').toUpperCase(), style: const TextStyle(color: _yellow, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .6)),
        const Spacer(),
        if (game.active && game.endsAt != null) _Countdown(game: game),
      ]),
      const SizedBox(height: 4),
      Text(game.question, style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w800, height: 1.3)),
      const SizedBox(height: 8),
      for (var i = 0; i < game.options.length; i++) ...[
        Container(
          height: 44,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: done && game.winnerOption == i ? const Color(0xFF69F0AE) : Colors.white24, width: done && game.winnerOption == i ? 2 : 1)),
          child: Stack(children: [
            Positioned.fill(
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: total == 0 ? 0.0 : (i < votes.length ? votes[i] / total : 0.0).clamp(0.0, 1.0).toDouble(),
                child: Container(decoration: BoxDecoration(color: _amber.withOpacity(.3), borderRadius: BorderRadius.circular(11))),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(children: [
                Text(String.fromCharCode(65 + i), style: const TextStyle(color: _yellow, fontWeight: FontWeight.w800)),
                const SizedBox(width: 8),
                Expanded(child: Text(game.options[i], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))),
                Text(total == 0 ? '0 %' : '${((i < votes.length ? votes[i] : 0) * 100 / total).round()} %', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
                if (game.active && !isHost) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onStoryVote == null ? null : () => onStoryVote!(i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(color: _amber, borderRadius: BorderRadius.circular(12)),
                      child: Text('${context.tr('Voter')} · ${game.voteCoins}', style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 6),
      ],
      Text(
        game.active ? '${CoinCheckout.fmt(total)} pcs · ${context.tr('Chaque vote compte, tu peux voter autant de fois que tu veux.')}' : context.tr('Le public a choisi la suite.'),
        style: const TextStyle(color: Colors.white54, fontSize: 10.5),
      ),
    ]);
  }

  /// Quiz à cagnotte : une question à la fois, bonne réponse montrée après le temps, classement en direct.
  Widget _quiz(BuildContext context) {
    final q = game.quiz;
    final options = [for (final o in (q['options'] as List? ?? const [])) '$o'];
    final reveal = q['phase'] == 'reveal';
    final correct = (q['correct'] as num?)?.toInt();
    final mine = (q['my_option'] as num?)?.toInt();
    final ranking = (q['ranking'] as List? ?? const []);
    final pool = (q['pool'] as num?)?.toInt() ?? 0;
    final done = !game.active;
    return _frame([
      Row(children: [
        Text('${context.tr('Question')} ${((q['index'] as num?)?.toInt() ?? 0) + 1}/${q['total']}'.toUpperCase(), style: const TextStyle(color: _yellow, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .6)),
        const SizedBox(width: 8),
        if (pool > 0) Text('${CoinCheckout.fmt(pool)} pcs', style: const TextStyle(color: _amber, fontSize: 11, fontWeight: FontWeight.w800)),
        const Spacer(),
        if (!done)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: (q['left'] as num? ?? 99) < 5 && !reveal ? Colors.red.withOpacity(.85) : Colors.black54, borderRadius: BorderRadius.circular(10)),
            child: Text(reveal ? context.tr('Réponse') : clock((q['left'] as num?)?.toInt() ?? 0), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
          ),
      ]),
      const SizedBox(height: 4),
      if (!done) ...[
        Text('${q['text']}', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800, height: 1.3)),
        const SizedBox(height: 8),
        for (var i = 0; i < options.length; i++)
          GestureDetector(
            onTap: (!isHost && !reveal && mine == null && onAnswer != null) ? () => onAnswer!(i) : null,
            child: Container(
              height: 40,
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: reveal && correct == i ? const Color(0xFF2ECC71).withOpacity(.3) : (reveal && mine == i ? Colors.red.withOpacity(.25) : Colors.black.withOpacity(.3)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: reveal && correct == i ? const Color(0xFF2ECC71) : (mine == i ? _amber : Colors.white24), width: mine == i || (reveal && correct == i) ? 2 : 1),
              ),
              child: Row(children: [
                Text(String.fromCharCode(65 + i), style: const TextStyle(color: _yellow, fontWeight: FontWeight.w800)),
                const SizedBox(width: 8),
                Expanded(child: Text(options[i], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))),
                if (!reveal && mine == i) Text(context.tr('ton choix'), style: const TextStyle(color: _amber, fontSize: 10.5)),
              ]),
            ),
          ),
      ],
      if (done)
        for (final w in game.winners)
          Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text('${['🥇', '🥈', '🥉'][((w as Map)['rank'] as int) - 1]}  ${(w)['coins']} pcs', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700))),
      if (ranking.isNotEmpty) ...[
        const SizedBox(height: 2),
        Text(context.tr('Classement').toUpperCase(), style: const TextStyle(color: _yellow, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .6)),
        for (var i = 0; i < ranking.length && i < 3; i++)
          Row(children: [
            Text(['🥇', '🥈', '🥉'][i]),
            const SizedBox(width: 6),
            Expanded(child: Text('${(ranking[i] as Map)['username'] ?? ''}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
            Text('${(ranking[i] as Map)['points']} pts', style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
          ]),
        if (!isHost && q['my_rank'] != null) Text('${context.tr('Toi')} : ${q['my_rank']}e · ${q['my_points']} pts', style: const TextStyle(color: _yellow, fontSize: 11.5, fontWeight: FontWeight.w700)),
      ],
    ]);
  }

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
Future<String?> showGamesMenu(BuildContext context, {required bool hasStageGuests, required bool gameActive, Set<String>? allowed}) {
  bool ok(String k) => allowed == null || allowed.contains(k);
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
          if (ok('goal')) item(ctx, 'goal', Icons.flag_rounded, ctx.tr('Objectif du live'), ctx.tr('Une barre qui monte avec les cadeaux')),
          if (ok('duel')) item(ctx, 'duel', Icons.sports_mma_rounded, ctx.tr('Duel 1 contre 1'), hasStageGuests ? ctx.tr('5 minutes, les cadeaux décident') : ctx.tr('Invite d\'abord quelqu\'un sur scène'), enabled: hasStageGuests),
          if (ok('challenge')) item(ctx, 'challenge', Icons.groups_rounded, ctx.tr('Défi à plusieurs'), hasStageGuests ? ctx.tr('Le premier à l\'objectif gagne') : ctx.tr('Invite d\'abord des présentateurs sur scène'), enabled: hasStageGuests),
          if (ok('poll')) item(ctx, 'poll', Icons.poll_rounded, ctx.tr('Sondage'), ctx.tr('Le public vote en direct')),
          if (ok('story')) item(ctx, 'story', Icons.auto_stories_rounded, ctx.tr('Conte interactif'), ctx.tr('Le public vote la suite avec des pièces')),
          if (ok('quiz')) item(ctx, 'quiz', Icons.quiz_rounded, ctx.tr('Quiz à cagnotte'), ctx.tr('Gratuit pour jouer, cagnotte offerte par toi')),
          if (ok('clips')) item(ctx, 'clips', Icons.movie_filter_rounded, ctx.tr('Clips rémunérés'), ctx.tr('Une prime pour les meilleurs moments')),
          if (ok('questions')) item(ctx, 'questions', Icons.help_outline_rounded, ctx.tr('Questions du public'), ctx.tr('Lis et épingle une question')),
          if (ok('draw')) item(ctx, 'draw', Icons.card_giftcard_rounded, ctx.tr('Tirage au sort'), ctx.tr('Mets des pièces en jeu')),
          if (gameActive) item(ctx, 'end', Icons.stop_circle_rounded, ctx.tr('Arrêter et retirer le jeu'), ctx.tr('Il disparaît de l\'écran, il reste dans l\'historique')),
          const SizedBox(height: 12),
        ]),
      ),
    ),
  );
}

/// Petit formulaire de texte et de nombre en fenêtre (objectif, tirage, sondage).
/// Avec [minuteChoices] : une ligne « Durée » à choisir ; les minutes choisies sont ajoutées en dernier élément du résultat.
Future<List<String>?> askFields(BuildContext context, {required String title, required List<({String label, String hint, bool number, String initial})> fields, String ok = 'Valider', List<int>? minuteChoices, int? initialMinutes}) {
  final ctrls = [for (final f in fields) TextEditingController(text: f.initial)];
  var minutes = initialMinutes ?? minuteChoices?.first ?? 0;
  return showDialog<List<String>>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < fields.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(controller: ctrls[i], keyboardType: fields[i].number ? TextInputType.number : TextInputType.text, decoration: InputDecoration(labelText: fields[i].label, hintText: fields[i].hint)),
            ),
          if (minuteChoices != null) ...[
            Align(alignment: Alignment.centerLeft, child: Text(ctx.tr('Durée'), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700))),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(spacing: 6, runSpacing: 4, children: [
                for (final m in minuteChoices)
                  ChoiceChip(key: ValueKey('minutes_$m'), label: Text(ctx.tr('{n} min', {'n': m})), selected: minutes == m, onSelected: (_) => setD(() => minutes = m)),
              ]),
            ),
          ],
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.tr('Annuler'))),
        FilledButton(onPressed: () => Navigator.pop(ctx, [for (final c in ctrls) c.text.trim(), if (minuteChoices != null) '$minutes']), child: Text(ctx.tr(ok))),
      ],
    )),
  );
}

/// Durées proposées à l'hôte pour un sondage (décision du 15/11/2026) ; le serveur accepte de 1 à 30 minutes.
const List<int> kPollMinuteChoices = [1, 2, 5, 10, 30];

/// Un sondage saisi : la question, ses choix remplis et sa durée.
({String question, List<String> options, int minutes}) pollFromFields(List<String> v) =>
    (question: v[0], options: [for (final o in v.sublist(1, v.length - 1)) if (o.isNotEmpty) o], minutes: int.tryParse(v.last) ?? 2);


/// Temps maximal pour répondre à une question de quiz : 30 minutes (décision du 15/11/2026), comme sur le serveur.
const int kQuizMaxSeconds = 1800;

/// Durées proposées à l'hôte pour chaque question.
const List<int> kQuizSecondsChoices = [15, 30, 60, 120, 300, 600, 900, 1800];

/// « 15 s », « 2 min », « 1 min 30 s ».
String quizDurationLabel(BuildContext context, int seconds) {
  if (seconds < 60) return context.tr('{n} s', {'n': seconds});
  final m = seconds ~/ 60, r = seconds % 60;
  return r == 0 ? context.tr('{n} min', {'n': m}) : context.tr('{m} min {s} s', {'m': m, 's': r});
}

/// Saisie d'un quiz : une question par ligne, `Question ? | A | B* | C` (étoile = bonne réponse), cagnotte offerte et durée par question.
Future<({List<QuizDraft> questions, int pool, int seconds})?> askQuiz(BuildContext context) {
  final text = TextEditingController();
  final pool = TextEditingController(text: '500');
  var seconds = 15;   // temps pour répondre à chaque question (15 s à 30 min)
  String? error;
  return showDialog<({List<QuizDraft> questions, int pool, int seconds})>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => AlertDialog(
        title: Text(ctx.tr('Quiz à cagnotte')),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ctx.tr('Une question par ligne : Question ? | choix A | choix B* | choix C. L\'étoile marque la bonne réponse. 10 questions au plus.'), style: const TextStyle(fontSize: 12.5, height: 1.4)),
            const SizedBox(height: 8),
            TextField(controller: text, minLines: 4, maxLines: 8, onChanged: (_) => setD(() {}), decoration: InputDecoration(border: const OutlineInputBorder(), hintText: ctx.tr('Capitale du Ghana ? | Kumasi | Accra* | Lomé'))),
            const SizedBox(height: 8),
            TextField(controller: pool, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: ctx.tr('Cagnotte offerte (pièces, 0 pour jouer sans gain)'))),
            const SizedBox(height: 10),
            Text(ctx.tr('Temps par question'), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 4, children: [
              for (final s in kQuizSecondsChoices)
                ChoiceChip(key: ValueKey('quiz_secs_$s'), label: Text(quizDurationLabel(ctx, s)), selected: seconds == s, onSelected: (_) => setD(() => seconds = s)),
            ]),
            Builder(builder: (_) {
              final n = QuizDraft.parse(text.text)?.length ?? 0;
              if (n == 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(ctx.tr('Durée totale du quiz : environ {d} ({n} questions)', {'d': quizDurationLabel(ctx, n * (seconds + 4)), 'n': n}), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              );
            }),
            const SizedBox(height: 6),
            Text(ctx.tr('Jouer est gratuit pour le public. La cagnotte est mise de côté maintenant : 50 % / 30 % / 20 % aux trois premiers, le reste te revient.'), style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
            if (error != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12))),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.tr('Annuler'))),
          FilledButton(
            onPressed: () {
              final qs = QuizDraft.parse(text.text);
              if (qs == null) {
                setD(() => error = ctx.tr('Chaque ligne : une question, 2 à 4 choix, une seule bonne réponse marquée par une étoile.'));
                return;
              }
              Navigator.pop(ctx, (questions: qs, pool: (int.tryParse(pool.text) ?? 0).clamp(0, 100000), seconds: seconds.clamp(8, kQuizMaxSeconds)));
            },
            child: Text(ctx.tr('Lancer')),
          ),
        ],
      ),
    ),
  );
}

/// Historique des quiz du live : pour chaque quiz, le podium puis les questions DÉJÀ révélées avec la bonne réponse, la réponse de la personne et le taux de réussite.
/// (La question en cours n'y figure jamais : aucune triche possible.)
class LiveQuizHistorySheet extends StatelessWidget {
  const LiveQuizHistorySheet({super.key, required this.future});
  final Future<List<Map<String, dynamic>>> future;

  static String _time(String? iso) {
    final d = DateTime.tryParse(iso ?? '')?.toLocal();
    if (d == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * .78,
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF26223A), Color(0xFF15121F)]),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(children: [
        const SizedBox(height: 8),
        Container(width: 38, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(99))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
          child: Row(children: [
            Expanded(child: Text(context.tr('Historique du quiz'), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
            IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white54), onPressed: () => Navigator.pop(context)),
          ]),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: future,
            builder: (ctx, snap) {
              if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator(color: _amber));
              final items = snap.data ?? const [];
              final shown = items.where((g) => ((g['questions'] as List?) ?? const []).isNotEmpty).toList();
              if (snap.hasError || shown.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(snap.hasError ? ctx.tr('Historique indisponible pour le moment.') : ctx.tr('Aucune question révélée pour l\'instant. Les questions et leurs bonnes réponses apparaissent ici après chaque manche.'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, height: 1.4)),
                  ),
                );
              }
              return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [for (final g in shown) _quiz(ctx, g)]);
            },
          ),
        ),
      ]),
    );
  }

  Widget _quiz(BuildContext ctx, Map<String, dynamic> g) {
    final qs = ((g['questions'] as List?) ?? const []).cast<Map>();
    final podium = ((g['podium'] as List?) ?? const []).cast<Map>();
    final ended = g['status'] == 'ended';
    const medals = ['🥇', '🥈', '🥉'];
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white.withOpacity(.06), borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${ctx.tr('Quiz de {h}', {'h': _time(g['started_at'] as String?)})} · ${ended ? ctx.tr('terminé') : ctx.tr('en cours')} · ${qs.length}/${g['total']}', style: const TextStyle(color: _yellow, fontWeight: FontWeight.w800, fontSize: 13)),
        if (ended && podium.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final p in podium)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text('${medals[((p['rank'] as num).toInt() - 1).clamp(0, 2)]}  @${p['username'] ?? ''} · ${p['points']} pts${(p['coins'] as num? ?? 0) > 0 ? ' · +${p['coins']} ${ctx.tr('pièces')}' : ''}', style: const TextStyle(color: Colors.white, fontSize: 12.5)),
            ),
        ],
        for (final q in qs) ...[
          const SizedBox(height: 14),
          Text('${(q['index'] as num).toInt() + 1}. ${q['text']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 6),
          for (var i = 0; i < ((q['options'] as List?) ?? const []).length; i++) _option(ctx, q, i),
          const SizedBox(height: 2),
          Text(_rate(ctx, q), style: const TextStyle(color: Colors.white54, fontSize: 11.5)),
        ],
      ]),
    );
  }

  String _rate(BuildContext ctx, Map q) {
    final n = (q['answers'] as num?)?.toInt() ?? 0;
    final ok = (q['correct_count'] as num?)?.toInt() ?? 0;
    if (n == 0) return ctx.tr('Personne n\'a répondu.');
    return ctx.tr('{p} % de bonnes réponses ({ok} sur {n})', {'p': '${(ok * 100 / n).round()}', 'ok': '$ok', 'n': '$n'});
  }

  Widget _option(BuildContext ctx, Map q, int i) {
    final correct = (q['correct'] as num?)?.toInt();
    final mine = (q['my_option'] as num?)?.toInt();
    final isCorrect = i == correct;
    final isMineWrong = i == mine && !isCorrect;
    final color = isCorrect ? const Color(0xFF69F0AE) : (isMineWrong ? const Color(0xFFFF8A80) : Colors.white24);
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: color.withOpacity(isCorrect || isMineWrong ? .14 : .04), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(isCorrect || isMineWrong ? .8 : .25))),
      child: Row(children: [
        Expanded(child: Text('${(q['options'] as List)[i]}', style: TextStyle(color: isCorrect || isMineWrong ? Colors.white : Colors.white70, fontSize: 13))),
        if (isCorrect) const Icon(Icons.check_circle_rounded, color: Color(0xFF69F0AE), size: 18),
        if (isMineWrong) const Icon(Icons.cancel_rounded, color: Color(0xFFFF8A80), size: 18),
        if (i == mine && isCorrect) Padding(padding: const EdgeInsets.only(left: 6), child: Text(ctx.tr('ta réponse'), style: const TextStyle(color: Color(0xFF69F0AE), fontSize: 10.5))),
        if (isMineWrong) Padding(padding: const EdgeInsets.only(left: 6), child: Text(ctx.tr('ta réponse'), style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 10.5))),
      ]),
    );
  }
}

/// Historique de TOUS les jeux du live (duel, défi, sondage, conte, quiz), le plus récent d'abord : résultat, gagnant, pièces reçues par chaque présentateur.
/// Les gains d'un duel ou d'un défi sont les cadeaux reçus (70 %), versés sur le compte « pièces gagnées » de CHAQUE présentateur ; le gagnant n'a pas de lot en plus.
class LiveGamesHistorySheet extends StatelessWidget {
  const LiveGamesHistorySheet({super.key, required this.future, this.onQuiz});
  final Future<List<Map<String, dynamic>>> future;

  /// Ouvre les questions et réponses du quiz (feuille dédiée).
  final VoidCallback? onQuiz;

  static String _time(String? iso) {
    final d = DateTime.tryParse(iso ?? '')?.toLocal();
    if (d == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * .78,
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF26223A), Color(0xFF15121F)]),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(children: [
        const SizedBox(height: 8),
        Container(width: 38, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(99))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
          child: Row(children: [
            Expanded(child: Text(context.tr('Historique des jeux'), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
            IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white54), onPressed: () => Navigator.pop(context)),
          ]),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: future,
            builder: (ctx, snap) {
              if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator(color: _amber));
              final items = snap.data ?? const [];
              if (snap.hasError || items.isEmpty) {
                return Center(child: Padding(padding: const EdgeInsets.all(32), child: Text(snap.hasError ? ctx.tr('Historique indisponible pour le moment.') : ctx.tr('Aucun jeu pour l\'instant dans ce live.'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, height: 1.4))));
              }
              return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [for (final g in items) _card(ctx, LiveGame(g))]);
            },
          ),
        ),
      ]),
    );
  }

  static String _title(BuildContext c, LiveGame g) => switch (g.kind) {
        'duel' => c.tr('Duel'),
        'challenge' => c.tr('Défi à plusieurs'),
        'poll' => c.tr('Sondage'),
        'story' => c.tr('Conte interactif'),
        'quiz' => c.tr('Quiz'),
        'draw' => c.tr('Tirage au sort'),
        _ => c.tr('Jeu'),
      };

  Widget _card(BuildContext ctx, LiveGame g) {
    final started = _time(g.raw['started_at'] as String?);
    final status = g.active ? ctx.tr('en cours') : ctx.tr('terminé');
    final lines = <Widget>[];
    if (g.isMatch) {
      final ps = g.players;
      final w = g.winnerId;
      if (!g.active) {
        lines.add(Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(w == null ? ctx.tr('Égalité : pas de gagnant') : '🏆 ${ctx.tr('Gagnant')} : @${ps.where((p) => p.id == w).map((p) => p.username).firstOrNull ?? ''}', style: const TextStyle(color: Color(0xFF69F0AE), fontWeight: FontWeight.w800, fontSize: 13.5)),
        ));
      }
      for (final p in ps) {
        final e = g.earnedOf(p.id);
        lines.add(Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(children: [
            StageAvatarMini(user: p),
            const SizedBox(width: 8),
            Expanded(child: Text('@${p.username}${p.id == w ? ' 🏆' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13))),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${CoinCheckout.fmt(g.score(p.id))} ${ctx.tr('pcs reçues en cadeaux')}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
              Text('+${CoinCheckout.fmt(e.earned)} ${ctx.tr('sur son compte')}', style: const TextStyle(color: _amber, fontSize: 11, fontWeight: FontWeight.w800)),
            ]),
          ]),
        ));
        final tg = g.topGiversOf(p.id);
        if (tg.isNotEmpty) {
          lines.add(Padding(
            padding: const EdgeInsets.only(top: 2, left: 36),
            child: Text(ctx.tr('Meilleurs donateurs') + ' : ' + [for (var i = 0; i < tg.length && i < 3; i++) '${['🥇', '🥈', '🥉'][i]} @${tg[i].username} ${CoinCheckout.fmt(tg[i].coins)}'].join('  '), style: const TextStyle(color: Color(0xFFFFD27A), fontSize: 10.5)),
          ));
        }
      }
      lines.add(Padding(padding: const EdgeInsets.only(top: 8), child: Text(ctx.tr('Chaque présentateur reçoit 70 % des cadeaux qui lui sont envoyés, sur son propre compte (pièces gagnées). Le gagnant n\'a pas de lot en plus.'), style: const TextStyle(color: Colors.white38, fontSize: 10.5, height: 1.3))));
    } else if (g.kind == 'draw') {
      final res = (g.raw['result'] as Map?) ?? const {};
      final w = (g.raw['winner'] as Map?)?['username'];
      lines.add(Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text('🎉 @${w ?? ''} ${ctx.tr('gagne')} ${CoinCheckout.fmt((res['coins'] as num?)?.toInt() ?? 0)} ${ctx.tr('pièces')}', style: const TextStyle(color: Color(0xFF69F0AE), fontWeight: FontWeight.w800, fontSize: 13)),
      ));
      lines.add(Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Text('${ctx.tr('Tiré au sort parmi')} ${(res['candidates'] as num?)?.toInt() ?? 0} ${ctx.tr('personnes')} · ${ctx.tr('lot mis en jeu par l\'hôte')} : ${CoinCheckout.fmt((res['staked'] as num?)?.toInt() ?? 0)} ${ctx.tr('pièces')}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ));
    } else if (g.kind == 'poll' || g.kind == 'story') {
      final votes = g.votes;
      final opts = g.options;
      final total = votes.fold<int>(0, (a, b) => a + b);
      for (var i = 0; i < opts.length; i++) {
        final v = i < votes.length ? votes[i] : 0;
        final win = !g.active && g.winnerOption == i;
        lines.add(Padding(padding: const EdgeInsets.only(top: 4), child: Text('${win ? '✅ ' : ''}${opts[i]} · $v ${g.kind == 'story' ? ctx.tr('pièces') : ctx.tr('voix')}${total > 0 ? ' (${(v * 100 / total).round()} %)' : ''}', style: TextStyle(color: win ? const Color(0xFF69F0AE) : Colors.white70, fontSize: 12.5, fontWeight: win ? FontWeight.w800 : FontWeight.w500))));
      }
      if (g.question.isNotEmpty) lines.insert(0, Text(g.question, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13.5)));
    } else if (g.kind == 'quiz') {
      for (final w in g.winners.cast<Map>()) {
        lines.add(Padding(padding: const EdgeInsets.only(top: 4), child: Text('${['🥇', '🥈', '🥉'][((w['rank'] as num?)?.toInt() ?? 1).clamp(1, 3) - 1]} @${w['username'] ?? ''} · +${w['coins']} ${ctx.tr('pièces')}', style: const TextStyle(color: Colors.white, fontSize: 12.5))));
      }
      if (onQuiz != null) lines.add(Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: onQuiz, child: Text(ctx.tr('Voir les questions et les réponses')))));
    }
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white.withOpacity(.06), borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${_title(ctx, g)} · $started · $status', style: const TextStyle(color: _yellow, fontWeight: FontWeight.w800, fontSize: 13)),
        ...lines,
      ]),
    );
  }
}
