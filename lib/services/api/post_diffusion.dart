/// Carte « Diffusion » d'une publication (vagues de diffusion, 08/11/2026) : visible par tous, jamais de noms de personnes.
/// `state` : testing (en cours de test), promising (plaît, passe bientôt à la vague suivante), stopped (restée discrète), top (au sommet, onglet Viral).
class PostDiffusion {
  final String state;
  final int level;
  final int levels;
  final int shownTotal;
  final int shownOutside;
  final int? finishedPct;
  final int? loopsPct;
  final int shares;
  final bool isVideo;
  final bool mine;

  const PostDiffusion({
    required this.state,
    required this.level,
    required this.levels,
    required this.shownTotal,
    required this.shownOutside,
    required this.finishedPct,
    required this.loopsPct,
    required this.shares,
    required this.isVideo,
    required this.mine,
  });

  factory PostDiffusion.fromJson(Map<String, dynamic> j) {
    int n(dynamic v) => (v as num?)?.toInt() ?? 0;
    return PostDiffusion(
      state: (j['state'] as String?) ?? 'testing',
      level: n(j['level']),
      levels: n(j['levels']) == 0 ? 5 : n(j['levels']),
      shownTotal: n(j['shown_total']),
      shownOutside: n(j['shown_outside']),
      finishedPct: (j['finished_pct'] as num?)?.toInt(),
      loopsPct: (j['loops_pct'] as num?)?.toInt(),
      shares: n(j['shares']),
      isVideo: j['is_video'] == true,
      mine: j['mine'] == true,
    );
  }
}
