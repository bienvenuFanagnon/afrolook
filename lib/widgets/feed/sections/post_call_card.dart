import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../l10n/tr.dart';
import '../../../pages/create/create_hub_page.dart';
import '../../../providers/authProvider.dart';
import '../../../theme/app_colors.dart';

/// Les phrases d'appel à poster : une accroche et une ligne qui rassure. `{a}` est remplacé par le prénom ou le pseudo de la personne.
class PostCallPhrases {
  PostCallPhrases._();

  static const List<({String title, String sub})> all = [
    (title: '{a}, qu\'est-ce qui se passe chez toi aujourd\'hui ?', sub: 'Montre-le en 15 secondes : on a hâte de te voir.'),
    (title: 'Ta voix compte.', sub: 'Laisse un message vocal à ta communauté, sans montrer ton visage.'),
    (title: 'Un sourire, une idée, un moment.', sub: 'Filme-le maintenant et partage-le avec tout le monde.'),
    (title: 'Ton quartier mérite d\'être vu.', sub: 'Filme ce qui fait ta ville, ta rue, ton marché.'),
    (title: 'Dis bonjour à tes abonnés !', sub: 'Une vidéo de 10 secondes suffit pour leur faire plaisir.'),
    (title: 'Les gens veulent te voir, pas seulement te lire.', sub: 'Une vidéo, c\'est le plus court chemin vers ta communauté.'),
    (title: 'Ton histoire du jour en 30 secondes ?', sub: 'Raconte-la à ta façon : on t\'écoute.'),
    (title: 'Un conseil, une astuce, un talent ?', sub: 'Montre-le : quelqu\'un en a besoin aujourd\'hui.'),
    (title: '{a}, c\'est ton moment.', sub: 'Filme-toi, choisis un look, publie. Ça prend une minute.'),
    (title: 'Chante, danse, rigole.', sub: 'Ce que tu fais de mieux mérite un public.'),
    (title: 'Un petit mot pour tes abonnés ?', sub: 'Enregistre-le en vocal : c\'est rapide et ça fait chaud au cœur.'),
    (title: 'Montre ce que tu fais aujourd\'hui.', sub: 'Ton travail, ton repas, ta tenue : tout le monde est curieux.'),
    (title: 'Ta journée vaut la peine d\'être racontée.', sub: 'Quelques secondes de vidéo, et c\'est partagé.'),
    (title: 'Et si tu essayais un nouveau look ?', sub: 'Nos looks rendent chaque photo et chaque vidéo plus belle.'),
  ];

  /// Phrase du jour pour un emplacement du fil : change d'un jour à l'autre et d'un emplacement à l'autre, sans hasard (stable pendant la session).
  static int indexFor(DateTime day, int slot) => (day.year * 366 + day.month * 31 + day.day + slot * 5) % all.length;

  static String fill(String text, String name) {
    var t = text.replaceAll('{a}', name).trim();
    t = t.replaceFirst(RegExp(r'^[,\s]+'), '');
    if (t.isEmpty) return t;
    return t[0].toUpperCase() + t.substring(1);
  }
}

/// Carte d'appel à poster dans le fil : de temps en temps, une phrase différente invite à se filmer ou à laisser un message vocal.
///
/// Discrète : au plus 3 par jour et par personne, la croix la masque jusqu'à demain, jamais sur le web. Les boutons ouvrent directement la caméra ou le micro.
class PostCallCard extends StatefulWidget {
  const PostCallCard({super.key, required this.slot});

  /// Emplacement dans le fil : fait varier la phrase.
  final int slot;

  static const int maxPerDay = 3;

  @override
  State<PostCallCard> createState() => _PostCallCardState();
}

class _PostCallCardState extends State<PostCallCard> {
  static const _kDay = 'post_call_day';
  static const _kCount = 'post_call_count';
  static const _kHidden = 'post_call_hidden_day';

  /// Emplacements déjà comptés pendant cette session (une carte recréée par le défilement ne compte qu'une fois).
  static final Set<String> _counted = {};

  bool _show = false;

  @override
  void initState() {
    super.initState();
    _decide();
  }

  static String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  Future<void> _decide() async {
    if (kIsWeb) return;
    try {
      final sp = await SharedPreferences.getInstance();
      final today = _today();
      if (sp.getString(_kHidden) == today) return;
      var count = sp.getString(_kDay) == today ? (sp.getInt(_kCount) ?? 0) : 0;
      final key = '$today#${widget.slot}';
      if (!_counted.contains(key)) {
        if (count >= PostCallCard.maxPerDay) return;
        count += 1;
        _counted.add(key);
        await sp.setString(_kDay, today);
        await sp.setInt(_kCount, count);
      }
      if (mounted) setState(() => _show = true);
    } catch (_) {}
  }

  Future<void> _hide() async {
    setState(() => _show = false);
    try {
      (await SharedPreferences.getInstance()).setString(_kHidden, _today());
    } catch (_) {}
  }

  void _open(CreateStart start) {
    HapticFeedback.selectionClick();
    final auth = context.read<UserAuthProvider>();
    auth.checkAppVersionAndProceed(context, () async {
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CreateHubPage(start: start)));
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_show) return const SizedBox.shrink();
    final c = AppColors.of(context);
    final me = context.read<UserAuthProvider>().loginUserData;
    final name = (me.pseudo ?? '').trim();
    final phrase = PostCallPhrases.all[PostCallPhrases.indexFor(DateTime.now(), widget.slot)];
    return Container(
      key: const ValueKey('post_call_card'),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.border),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c.surface, Color.lerp(c.surface, c.accent, c.isDark ? .09 : .16)!]),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(14)),
            child: Icon(Icons.videocam_rounded, color: c.onAccent, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  PostCallPhrases.fill(context.tr(phrase.title, {'a': name}), name),
                  style: TextStyle(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w800, height: 1.25),
                ),
                const SizedBox(height: 3),
                Text(context.tr(phrase.sub), style: TextStyle(color: c.textSecondary, fontSize: 12.8, height: 1.35)),
              ]),
            ),
          ),
          IconButton(
            key: const ValueKey('post_call_close'),
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.close_rounded, size: 18, color: c.textSecondary),
            tooltip: context.tr('Masquer jusqu\'à demain'),
            onPressed: _hide,
          ),
        ]),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Row(children: [
            Expanded(
              child: FilledButton.icon(
                key: const ValueKey('post_call_film'),
                onPressed: () => _open(CreateStart.video),
                icon: const Icon(Icons.fiber_manual_record_rounded, size: 16),
                label: Text(context.tr('Me filmer'), style: const TextStyle(fontWeight: FontWeight.w900)),
                style: FilledButton.styleFrom(backgroundColor: c.accent, foregroundColor: c.onAccent, padding: const EdgeInsets.symmetric(vertical: 12), shape: const StadiumBorder()),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey('post_call_voice'),
                onPressed: () => _open(CreateStart.audio),
                icon: Icon(Icons.mic_rounded, size: 18, color: c.textPrimary),
                label: Text(context.tr('Message vocal'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
                style: OutlinedButton.styleFrom(side: BorderSide(color: c.border), padding: const EdgeInsets.symmetric(vertical: 12), shape: const StadiumBorder()),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
