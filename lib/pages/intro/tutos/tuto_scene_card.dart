import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../l10n/tr.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/pseudo_tag.dart';
import '../../cards/card_tutorial_page.dart';
import 'tuto_catalog.dart';
import 'tuto_layouts.dart';

const _gold = Color(0xFFF5C542);

/// Or lisible dans les deux thèmes : l'or vif sur fond sombre, un ambre plus foncé sur fond clair.
Color _goldOn(AppColors c) => c.isDark ? _gold : const Color(0xFF8A5A00);

/// Fond des cartes « gain » (or très léger).
Color _goldBg(AppColors c) => c.isDark ? const Color(0xFF2A2410) : const Color(0xFFFFF4D6);

/// Un choix de rotation : [scene] null = « Tutoriel de monétisation » d'origine (animation du like).
class TutoPick {
  final TutoScene? scene;
  const TutoPick(this.scene);
}

/// Rotation des scènes. Dans les feeds : jusqu'à [dailyQuota] tutoriels DIFFÉRENTS par jour
/// (tous feeds confondus), toujours le suivant du cycle ; le créneau 0 est l'animation d'origine.
class TutoRotation {
  static const dailyQuota = 5;

  static String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  static Future<int> _countToday(SharedPreferences prefs) async {
    if (prefs.getString('tuto_day') != _today()) return 0;
    return prefs.getInt('tuto_day_count') ?? 0;
  }

  /// Combien de tutoriels peuvent encore être montrés aujourd'hui.
  static Future<int> remainingToday() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return dailyQuota - await _countToday(prefs);
    } catch (_) {
      return 0;
    }
  }

  /// Prend le tutoriel suivant du cycle ; null si les [dailyQuota] du jour sont déjà montrés.
  static Future<TutoPick?> takeToday() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final count = await _countToday(prefs);
      if (count >= dailyQuota) return null;
      final scenes = tutoScenesAvailable();
      final slots = scenes.length + 1; // +1 : animation d'origine
      final i = ((prefs.getInt('tuto_ptr') ?? -1) + 1) % slots;
      await prefs.setInt('tuto_ptr', i);
      await prefs.setString('tuto_day', _today());
      await prefs.setInt('tuto_day_count', count + 1);
      return TutoPick(i == 0 ? null : scenes[i - 1]);
    } catch (_) {
      return null;
    }
  }

  /// Avant la connexion : scène suivante parmi les scènes publiques (null = tutoriel d'origine).
  static Future<TutoPick> nextForLogin() async {
    final scenes = tutoScenesAvailable(publicOnly: true);
    var i = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      i = ((prefs.getInt('tuto_login_ptr') ?? -1) + 1) % (scenes.length + 1);
      await prefs.setInt('tuto_login_ptr', i);
    } catch (_) {}
    return TutoPick(i == 0 ? null : scenes[i - 1]);
  }

  /// Avant la connexion : une scène tous les 2 jours.
  static const _gate = Duration(days: 2);

  static Future<bool> loginSceneDue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getInt('tuto_login_scene_last') ?? 0;
      return DateTime.now().millisecondsSinceEpoch - last >= _gate.inMilliseconds;
    } catch (_) {
      return false;
    }
  }

  static Future<void> markLoginSceneShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('tuto_login_scene_last', DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }
}

/// Téléphone animé : la vraie page de l'app, l'action clé mise en lumière (halo, doigt, bulle),
/// puis le gain qui tombe. Boucle de 9 s.
class TutoPhone extends StatefulWidget {
  final TutoScene scene;
  const TutoPhone({super.key, required this.scene});

  @override
  State<TutoPhone> createState() => _TutoPhoneState();
}

class _TutoPhoneState extends State<TutoPhone> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 9))..repeat();

  static const _green = Color(0xFF2ECC71);
  static const _greenInk = Color(0xFF06331A);
  static const _goldInk = Color(0xFF412402);
  static const _pink = Color(0xFFE91E8C);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _seg(double t, double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);

  Widget _el(BuildContext ctx, AppColors c, MockEl e) {
    switch (e.kind) {
      case MockKind.cover:
        return Container(
          height: e.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: const LinearGradient(colors: [Color(0xFF1E5D3A), Color(0xFF8A6D18)]),
          ),
        );
      case MockKind.profile:
        return SizedBox(
          height: e.height,
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, gradient: LinearGradient(colors: [_green, _gold])),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                PseudoTag(label: e.a.startsWith('@') ? e.a : ctx.tr(e.a), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 12)),
                Text(ctx.tr(e.b), style: TextStyle(color: c.textSecondary, fontSize: 11)),
              ]),
            ),
          ]),
        );
      case MockKind.line:
        return Container(height: 8, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(4)));
      case MockKind.tile:
        return Container(
          height: e.height,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(color: c.surfaceVariant, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(ctx.tr(e.a),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 11.5)),
                if (e.b.isNotEmpty)
                  Text(ctx.tr(e.b), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textSecondary, fontSize: 10)),
              ]),
            ),
            if (e.trailing == 'on' || e.trailing == 'off')
              Container(
                width: 30,
                height: 17,
                padding: const EdgeInsets.all(2),
                alignment: e.trailing == 'on' ? Alignment.centerRight : Alignment.centerLeft,
                decoration: BoxDecoration(color: e.trailing == 'on' ? _green : c.border, borderRadius: BorderRadius.circular(9)),
                child: Container(width: 13, height: 13, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
              )
            else if (e.trailing.isNotEmpty)
              Text(e.trailing, style: TextStyle(color: _goldOn(c), fontWeight: FontWeight.w800, fontSize: 11.5)),
          ]),
        );
      case MockKind.button:
        final bg = e.color == 1 ? _gold : (e.color == 2 ? _pink : _green);
        final fg = e.color == 1 ? _goldInk : (e.color == 2 ? Colors.white : _greenInk);
        return Container(
          height: e.height,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
          child: Text(ctx.tr(e.a), style: TextStyle(color: fg, fontWeight: FontWeight.w900, fontSize: 11.5)),
        );
      case MockKind.chips:
        return SizedBox(
          height: e.height,
          child: Row(children: [
            for (final it in e.items)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: c.surfaceVariant, borderRadius: BorderRadius.circular(12)),
                child: Text(ctx.tr(it), style: TextStyle(color: c.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w700)),
              ),
          ]),
        );
      case MockKind.big:
        return Container(
          height: e.height,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(color: _goldBg(c), borderRadius: BorderRadius.circular(10)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ctx.tr(e.a), style: TextStyle(color: c.textSecondary, fontSize: 10.5)),
            Text(e.b, style: TextStyle(color: _goldOn(c), fontWeight: FontWeight.w900, fontSize: 20)),
          ]),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sc = widget.scene;
    final c = AppColors.of(context);
    // Position verticale de l'élément mis en lumière (barre 44 + marge 10, éléments espacés de 8)
    final custom = sc.layout != 'std' && sc.spot != null;
    var y = 54.0;
    if (custom) {
      y = sc.spot!.top;
    } else {
      for (var i = 0; i < sc.target; i++) {
        y += sc.els[i].height + 8;
      }
    }
    final MockEl? target = custom ? null : sc.els[sc.target];
    final th = custom ? sc.spot!.height : target!.height;
    final spotL = custom ? sc.spot!.left : 10.0;
    final spotR = custom ? sc.spot!.right : 10.0;
    final labelBelow = y + th < 290;

    return SizedBox(
      width: 240,
      height: 470,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(34),
          border: Border.all(color: const Color(0xFF26332C), width: 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Container(
            color: c.background,
            child: AnimatedBuilder(
              animation: _c,
              builder: (ctx, _) {
                final t = _c.value;
                final ring = _seg(t, .06, .12) * (1 - .65 * _seg(t, .40, .46));
                final dim = .55 * _seg(t, .06, .12) * (1 - _seg(t, .40, .50));
                final tapO = _seg(t, .38, .42) * (1 - _seg(t, .56, .60));
                final tapS = 1.6 - .6 * _seg(t, .38, .44) - .15 * _seg(t, .44, .52);
                final labelO = _seg(t, .08, .14) * (1 - _seg(t, .40, .48));
                final gainO = _seg(t, .54, .62) * (1 - _seg(t, .92, 1.0));
                final popO = _seg(t, .56, .62) * (1 - _seg(t, .84, .92));
                final popDy = 10 - 56 * _seg(t, .56, .92);

                return Stack(children: [
                  // 1) La vraie page (maquette)
                  if (custom)
                    Positioned.fill(
                      child: sc.layout == 'live'
                          ? tutoLayoutLive(ctx)
                          : sc.layout == 'live_prive'
                              ? tutoLayoutLivePrivate(ctx)
                              : Column(children: [
                                  Container(
                                    height: 44,
                                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
                                    color: c.surface,
                                    alignment: Alignment.centerLeft,
                                    child: Text(ctx.tr(sc.screenTitle),
                                        style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 12)),
                                  ),
                                  Expanded(child: sc.layout == 'comments' ? tutoLayoutComments(ctx, c) : tutoLayoutPost(ctx, c)),
                                ]),
                    )
                  else
                  Column(children: [
                    Container(
                      height: 44,
                      padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
                      color: c.surface,
                      alignment: Alignment.centerLeft,
                      child: Text(ctx.tr(sc.screenTitle),
                          style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 12)),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(children: [
                        for (var i = 0; i < sc.els.length; i++) ...[
                          _el(ctx, c, sc.els[i]),
                          const SizedBox(height: 8),
                        ],
                      ]),
                    ),
                  ]),
                  // 2) Le reste s'assombrit
                  if (!custom) Positioned.fill(child: IgnorePointer(child: Container(color: Colors.black.withOpacity(dim)))),
                  // 3) L'action en lumière : l'élément est redessiné au-dessus, avec son halo
                  Positioned(
                    top: y,
                    left: spotL,
                    right: spotR,
                    height: th,
                    child: Stack(clipBehavior: Clip.none, children: [
                      if (target != null) Positioned.fill(child: _el(ctx, c, target)),
                      Positioned(
                        left: -5,
                        right: -5,
                        top: -5,
                        bottom: -5,
                        child: Opacity(
                          opacity: ring,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(color: _gold, width: 2),
                              boxShadow: [BoxShadow(color: _gold.withOpacity(.5), blurRadius: 14)],
                            ),
                          ),
                        ),
                      ),
                    ]),
                  ),
                  // 4) Le doigt qui tape
                  Positioned(
                    top: y + th / 2 - 16,
                    right: 26,
                    child: Opacity(
                      opacity: tapO,
                      child: Transform.scale(
                        scale: tapS,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                              color: (c.isDark ? Colors.white : Colors.black).withOpacity(.25), shape: BoxShape.circle, border: Border.all(color: c.isDark ? Colors.white : Colors.black87, width: 2)),
                        ),
                      ),
                    ),
                  ),
                  // 5) La bulle qui explique
                  Positioned(
                    top: labelBelow ? y + th + 12 : y - 52,
                    left: 12,
                    right: 12,
                    child: Opacity(
                      opacity: labelO,
                      child: Transform.translate(
                        offset: Offset(0, 6 * (1 - _seg(t, .08, .14))),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(color: _gold, borderRadius: BorderRadius.circular(10)),
                          child: Text(ctx.tr(sc.hint),
                              style: const TextStyle(color: _goldInk, fontWeight: FontWeight.w900, fontSize: 11.5, height: 1.25)),
                        ),
                      ),
                    ),
                  ),
                  // 6) Le gain qui tombe
                  Positioned(
                    left: 74,
                    bottom: 84,
                    child: Opacity(
                      opacity: popO,
                      child: Transform.translate(
                        offset: Offset(0, popDy),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(color: _gold, borderRadius: BorderRadius.circular(12)),
                          child: Text('${sc.gainEmoji} +',
                              style: const TextStyle(color: _goldInk, fontWeight: FontWeight.w900, fontSize: 12)),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 14,
                    child: Opacity(
                      opacity: gainO,
                      child: Transform.translate(
                        offset: Offset(0, 16 * (1 - _seg(t, .54, .62))),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: _goldBg(c),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _goldOn(c), width: 1.5),
                          ),
                          child: Row(children: [
                            Text(sc.gainEmoji, style: const TextStyle(fontSize: 22)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                                Text(ctx.tr(sc.gainTitle),
                                    style: TextStyle(color: _goldOn(c), fontWeight: FontWeight.w900, fontSize: 15)),
                                Text(ctx.tr(sc.gainSub), style: TextStyle(color: c.textSecondary, fontSize: 10.5)),
                              ]),
                            ),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ]);
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Carte d'un tutoriel : titre, téléphone animé avec la vraie page, ce que le créateur peut gagner,
/// puis le bouton d'action de la scène.
class TutoSceneCard extends StatelessWidget {
  final TutoScene scene;
  final bool fullScreen;
  final VoidCallback? onClose;
  /// Remplace l'action de la scène (ex. avant login : ouvrir l'inscription).
  final VoidCallback? onActionOverride;
  final String? actionLabelOverride;
  final VoidCallback? onSeeAll;

  const TutoSceneCard({
    super.key,
    required this.scene,
    this.fullScreen = false,
    this.onClose,
    this.onActionOverride,
    this.actionLabelOverride,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final gold = _goldOn(c);
    // Dans les feeds, le téléphone est réduit (même proportions) pour ne pas occuper tout l'écran
    final scale = fullScreen ? 0.8 : 0.68;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: gold.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
            child: Text(context.tr('Le savais-tu ?'),
                style: TextStyle(color: gold, fontSize: 12, fontWeight: FontWeight.w800)),
          ),
          const Spacer(),
          if (onClose != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: onClose,
              icon: Icon(Icons.close_rounded, color: c.textSecondary, size: 20),
            ),
        ]),
        const SizedBox(height: 8),
        Text('${scene.emoji} ${context.tr(scene.title)}',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textPrimary, fontSize: fullScreen ? 22 : 20, fontWeight: FontWeight.w800, height: 1.2)),
        const SizedBox(height: 4),
        Text(context.tr(scene.hook),
            textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary, fontSize: 13.5, height: 1.4)),
        const SizedBox(height: 12),
        Center(
          child: SizedBox(
            width: 240 * scale,
            height: 470 * scale,
            child: FittedBox(fit: BoxFit.contain, child: TutoPhone(scene: scene)),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _goldBg(c),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: gold.withOpacity(0.5)),
          ),
          child: Column(children: [
            Text(context.tr(scene.earn),
                textAlign: TextAlign.center,
                style: TextStyle(color: gold, fontSize: 13.5, fontWeight: FontWeight.w800, height: 1.3)),
            const SizedBox(height: 2),
            Text(context.tr('Exemple de gains, à titre indicatif'),
                textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary, fontSize: 11)),
          ]),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: onActionOverride ?? () => scene.action?.call(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2ECC71),
            foregroundColor: const Color(0xFF06331A),
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Text(context.tr(actionLabelOverride ?? scene.actionLabel),
              style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
        if (onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
            child: Text(context.tr('Voir tous les tutoriels'), style: TextStyle(color: c.textSecondary)),
          ),
        if (fullScreen) ...[
          const SizedBox(height: 6),
          Text(context.tr('Glisse vers le haut pour continuer'),
              textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary, fontSize: 12)),
        ],
      ],
    );

    return Container(
      margin: fullScreen ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      padding: EdgeInsets.fromLTRB(16, fullScreen ? 50 : 14, 16, fullScreen ? 24 : 16),
      decoration: BoxDecoration(
        borderRadius: fullScreen ? null : BorderRadius.circular(22),
        border: fullScreen ? null : Border.all(color: gold.withOpacity(0.25)),
        gradient: RadialGradient(
          center: const Alignment(-0.8, -0.9),
          radius: 1.3,
          colors: [c.isDark ? const Color(0x331FAA59) : const Color(0x261FAA59), c.isDark ? const Color(0xFF070B09) : c.background],
        ),
      ),
      child: fullScreen ? Center(child: SingleChildScrollView(child: content)) : content,
    );
  }
}

/// Liste de tous les tutoriels, ouvrable depuis les cartes et le menu.
class TutoListPage extends StatelessWidget {
  /// Mode admin : toutes les scènes, y compris celles masquées sur iOS, avec leurs étiquettes.
  final bool showAll;
  const TutoListPage({super.key, this.showAll = false});

  @override
  Widget build(BuildContext context) {
    final scenes = showAll ? kTutoScenes : tutoScenesAvailable();
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        foregroundColor: c.textPrimary,
        elevation: 0,
        title: Text(context.tr('Tous les tutoriels')),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(14),
        itemCount: scenes.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, idx) {
          // Premier tutoriel : le Studio Cartes (exemples réels avec les images de l'application)
          if (idx == 0) {
            return InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CardTutorialPage())),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: c.primary.withOpacity(0.6), width: 1.5),
                ),
                child: Row(children: [
                  const Text('✨', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Flexible(child: Text(context.tr('Crée ta carte Afrolook'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 15))),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(5)),
                          child: const Text('NOUVEAU', style: TextStyle(color: Color(0xFF1F1F1F), fontSize: 9.5, fontWeight: FontWeight.w800)),
                        ),
                      ]),
                      const SizedBox(height: 2),
                      Text(context.tr('Transforme un post en carte à partager, avec des exemples.'), style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
                    ]),
                  ),
                  Icon(Icons.chevron_right_rounded, color: c.textSecondary),
                ]),
              ),
            );
          }
          final i = idx - 1;
          final s = scenes[i];
          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TutoScenePage(scene: s))),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _goldOn(c).withOpacity(0.3)),
              ),
              child: Row(children: [
                Text(s.emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${i + 1}. ${context.tr(s.title)}',
                        style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(context.tr(s.hook), style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
                    if (showAll)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          [
                            s.publicScene ? 'Avant connexion : oui' : 'Avant connexion : non',
                            if (s.hiddenOnIOS) 'Masquée sur iOS',
                          ].join(' · '),
                          style: TextStyle(color: _goldOn(c), fontSize: 11),
                        ),
                      ),
                  ]),
                ),
                Icon(Icons.chevron_right_rounded, color: c.textSecondary),
              ]),
            ),
          );
        },
      ),
    );
  }
}

/// Une scène en plein écran.
class TutoScenePage extends StatelessWidget {
  final TutoScene scene;
  final VoidCallback? onActionOverride;
  final String? actionLabelOverride;
  const TutoScenePage({super.key, required this.scene, this.onActionOverride, this.actionLabelOverride});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.of(context).background,
        body: SafeArea(
          child: SingleChildScrollView(
            child: TutoSceneCard(
              scene: scene,
              onClose: () => Navigator.of(context).maybePop(),
              onActionOverride: onActionOverride,
              actionLabelOverride: actionLabelOverride,
            ),
          ),
        ),
      );
}

/// Page affichée avant la connexion (une scène tous les 2 jours) : « Passer » ou l'action mènent au login.
class TutoBeforeLoginPage extends StatelessWidget {
  final TutoScene scene;
  final VoidCallback onDone;
  const TutoBeforeLoginPage({super.key, required this.scene, required this.onDone});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.of(context).background,
        body: SafeArea(
          child: SingleChildScrollView(
            child: TutoSceneCard(
              scene: scene,
              onClose: onDone,
              onActionOverride: onDone,
              actionLabelOverride: 'Me connecter ou créer mon compte',
            ),
          ),
        ),
      );
}
