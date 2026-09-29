import 'package:afrotok/widgets/pseudo_tag.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/tr.dart';
import '../../theme/app_colors.dart';
import '../../utils/platform_guard.dart';
import '../../widgets/post_coins_earned.dart';
import '../auth/authTest/Screens/Login/loginPageUser.dart';
import '../auth/eula_screen.dart';
import '../../services/currency_service.dart';
import 'tutos/tuto_catalog.dart';
import 'tutos/tuto_scene_card.dart';

/// Tutoriel animé (motion design) montré une seule fois, avant la connexion :
/// un like qui rapporte une pièce, trois posts dont les compteurs montent,
/// le total du mois en FCFA, puis félicitations et invitation à créer un compte.
class MonetizationTutorialPage extends StatefulWidget {
  /// true : ouvert depuis l'app (rappel du feed) — « Passer » ferme la page
  /// et la fin propose de créer un post au lieu de créer un compte.
  final bool inApp;
  const MonetizationTutorialPage({super.key, this.inApp = false});

  static const _seenKey = 'afrolook_tuto_monetisation_seen';

  static Future<bool> alreadySeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_seenKey) ?? false;
    } catch (_) {
      return true;
    }
  }

  static Future<void> markSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_seenKey, true);
    } catch (_) {}
  }

  @override
  State<MonetizationTutorialPage> createState() => _MonetizationTutorialPageState();
}

// ── Données de l'exemple ──────────────────────────────────────────────────────
// 1 like = 1 pièce (0,4 FCFA) ; vues payées 300 FCFA pour 1 000 vues (exemple).
const double _fcfaPerCoin = 0.4;
const double _rpm = 300;

class _DemoPost {
  final String image, pseudo, followers, text, flag;
  final int likesFrom, likes, views, comments, reposts, gifts;
  final double aspect;
  const _DemoPost(this.image, this.pseudo, this.followers, this.text, this.likesFrom, this.likes, this.views,
      this.comments, this.reposts, this.gifts, this.aspect, this.flag);
  double fcfa(double likesNow, double viewsNow) => likesNow * _fcfaPerCoin + viewsNow / 1000 * _rpm;
}

const _posts = [
  _DemoPost('assets/images/intro3.jpg', 'nadia.vibes', '12,4k', 'Ma routine selfie du matin ☀️ #afrostyle', 247, 3200,
      62000, 318, 42, 16, 16 / 9, '🇨🇮'),
  _DemoPost('assets/images/intro2.jpg', 'kofi.drip', '8,1k', 'Nouveau drip pour le week-end 🔥', 0, 1850, 36000, 204,
      27, 9, 4 / 5, '🇬🇭'),
  _DemoPost('assets/images/intro5.jpg', 'amara.art', '21,7k', 'Petit shooting improvisé 📸', 0, 5400, 94000, 611, 88,
      31, 4 / 5, '🇸🇳'),
];

/// Mode « vidéo marketing » (--dart-define=TUTO_VIDEO=true) : sans boutons
/// Passer/Revoir, clic automatique sur « Récupérer mes gains », sons journalisés
/// pour recaler la bande son sur l'enregistrement d'écran.
const bool _kVideoMode = bool.fromEnvironment('TUTO_VIDEO');

// ── Sons ──────────────────────────────────────────────────────────────────────
/// Lecteurs préchargés en mode faible latence (SoundPool sur Android), joués
/// sans attente ni verrou pour rester calés sur l'image.
class _Sfx {
  /// Pour le rendu vidéo hors appareil : reçoit les sons au lieu de les jouer.
  static void Function(String name, double volume)? hook;

  final Map<String, List<AudioPlayer>> _players = {};
  final Map<String, int> _next = {};
  int _lastTick = 0;
  bool ready = false;

  Future<void> load() async {
    if (hook != null) {
      ready = true;
      return;
    }
    const names = {'pop': 2, 'coin': 3, 'tick': 4, 'whoosh': 2, 'success': 1, 'rise': 1};
    final jobs = <Future<void>>[];
    for (final e in names.entries) {
      final list = <AudioPlayer>[];
      _players[e.key] = list;
      _next[e.key] = 0;
      for (var i = 0; i < e.value; i++) {
        final pl = AudioPlayer();
        list.add(pl);
        jobs.add(() async {
          try {
            await pl.setPlayerMode(PlayerMode.lowLatency);
            await pl.setReleaseMode(ReleaseMode.stop);
            await pl.setSource(AssetSource('sounds/tuto_${e.key}.wav'));
          } catch (_) {}
        }());
      }
    }
    await Future.wait(jobs);
    ready = true;
  }

  void play(String name, {double volume = 0.8}) {
    if (hook != null) return hook!(name, volume);
    final list = _players[name];
    if (list == null || list.isEmpty) return;
    final i = _next[name]!;
    _next[name] = (i + 1) % list.length;
    final pl = list[i];
    if (_kVideoMode) debugPrint('TUTO_SFX $name $volume ${DateTime.now().millisecondsSinceEpoch}');
    try {
      pl.setVolume(volume);
      pl.play(AssetSource('sounds/tuto_$name.wav'), volume: volume, mode: PlayerMode.lowLatency);
    } catch (_) {}
  }

  /// Tic des compteurs, limité à ~14 par seconde.
  void tick() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastTick < 70) return;
    _lastTick = now;
    play('tick', volume: 0.35);
  }

  void dispose() {
    for (final l in _players.values) {
      for (final p in l) {
        try {
          p.dispose();
        } catch (_) {}
      }
    }
  }
}

class _MonetizationTutorialPageState extends State<MonetizationTutorialPage> with TickerProviderStateMixin {
  static final _colors = AppColors.dark;
  static const _gold = Color(0xFFF5C542);

  final _sfx = _Sfx();
  final _stageKey = GlobalKey();
  final _heartKey = GlobalKey();
  final _walletKey = GlobalKey();

  late final AnimationController _bg = AnimationController(vsync: this, duration: const Duration(seconds: 14))..repeat();
  late final AnimationController _heartBounce =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  late final AnimationController _burst = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  late final AnimationController _fly = AnimationController(vsync: this, duration: const Duration(milliseconds: 850));
  late final AnimationController _confetti = AnimationController(vsync: this, duration: const Duration(seconds: 3));

  int _scene = 0; // 0 like, 1 posts, 2 total, 3 bravo
  List<_DemoPost> _demo = _posts;
  bool _alive = true;
  int _runId = 0;
  bool _live(int id) => _alive && id == _runId;

  // Scène 1
  bool _cardIn = false, _liked = false, _zoom = false, _tapRing = false, _walletBump = false;
  double _likes1 = 247;
  int _wallet = 0;
  Offset _flyFrom = Offset.zero, _flyTo = Offset.zero;
  bool _flying = false;

  // Scène 2
  int _postIndex = 0;
  double _pLikes = 0, _pViews = 0;
  double _runCoins = 0, _runFcfa = 0;

  // Scène 3
  double _total = 0;
  bool _claimReady = false;

  @override
  void initState() {
    super.initState();
    if (!widget.inApp) MonetizationTutorialPage.markSeen();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      for (final p in _posts) {
        precacheImage(AssetImage(p.image), context);
      }
      // Démarre quand les sons sont prêts (au plus 1,5 s d'attente)
      await _sfx.load().timeout(const Duration(milliseconds: 1500), onTimeout: () {});
      if (mounted) _run();
    });
  }

  @override
  void dispose() {
    _alive = false;
    _bg.dispose();
    _heartBounce.dispose();
    _burst.dispose();
    _fly.dispose();
    _confetti.dispose();
    _sfx.dispose();
    super.dispose();
  }

  Future<void> _wait(int ms) => Future.delayed(Duration(milliseconds: ms));

  /// Fait monter une valeur de [from] à [to] en [ms] (courbe douce) avec des tics.
  Future<void> _countUp(int id, double from, double to, int ms, void Function(double) onValue, {bool ticks = true}) async {
    final c = AnimationController(vsync: this, duration: Duration(milliseconds: ms));
    final a = CurvedAnimation(parent: c, curve: Curves.easeOutCubic);
    a.addListener(() {
      if (!_live(id)) {
        c.stop();
        return;
      }
      setState(() => onValue(from + (to - from) * a.value));
      if (ticks && c.value < 0.97) _sfx.tick();
    });
    try {
      await c.forward().orCancel;
    } catch (_) {}
    c.dispose();
  }

  Offset _centerOf(GlobalKey k) {
    final stage = _stageKey.currentContext?.findRenderObject() as RenderBox?;
    final box = k.currentContext?.findRenderObject() as RenderBox?;
    if (stage == null || box == null) return Offset.zero;
    return box.localToGlobal(box.size.center(Offset.zero), ancestor: stage);
  }

  /// Tire de nouveaux chiffres pour chaque lecture (jamais deux fois les mêmes montants).
  void _shuffle() {
    final r = math.Random();
    int around(int base, double spread) => (base * (1 - spread + r.nextDouble() * spread * 2)).round();
    _demo = [
      for (final p in _posts)
        _DemoPost(p.image, p.pseudo, p.followers, p.text, p.likesFrom, around(p.likes, 0.35), around(p.views, 0.4),
            around(p.comments, 0.4), around(p.reposts, 0.4), around(p.gifts, 0.5), p.aspect, p.flag),
    ];
    // Le total doit toujours dépasser 50 000 FCFA : on remonte les vues si besoin
    const minTotal = 52000.0;
    double total() => _demo.fold(0.0, (s, p) => s + p.fcfa(p.likes.toDouble(), p.views.toDouble()));
    final t = total();
    if (t < minTotal) {
      final likesPart = _demo.fold(0.0, (s, p) => s + p.likes * _fcfaPerCoin);
      final k = (minTotal - likesPart) / (t - likesPart) * (1 + r.nextDouble() * 0.25);
      _demo = [
        for (final p in _demo)
          _DemoPost(p.image, p.pseudo, p.followers, p.text, p.likesFrom, p.likes, (p.views * k).round(), p.comments,
              p.reposts, p.gifts, p.aspect, p.flag),
      ];
    }
  }

  Future<void> _run() async {
    final id = ++_runId;
    _shuffle();
    final first = _demo[0];
    // ── 1. Le like qui paie ────────────────────────────────────────────────────
    _sfx.play('whoosh', volume: 0.5);
    await _wait(200);
    if (!_live(id)) return;
    setState(() => _cardIn = true);
    await _wait(1400);
    if (!_live(id)) return;
    setState(() => _zoom = true);
    await _wait(750);
    if (!_live(id)) return;
    setState(() => _tapRing = true);
    await _wait(160);
    if (!_live(id)) return;
    HapticFeedback.lightImpact();
    _sfx.play('pop');
    setState(() {
      _liked = true;
      _likes1 = first.likesFrom + 1.0;
    });
    _heartBounce.forward(from: 0);
    _burst.forward(from: 0);
    await _wait(250);
    if (!_live(id)) return;
    // Pièce qui s'envole vers le porte-monnaie
    _flyFrom = _centerOf(_heartKey);
    _flyTo = _centerOf(_walletKey);
    setState(() {
      _flying = true;
      _tapRing = false;
    });
    await _fly.forward(from: 0);
    if (!_live(id)) return;
    HapticFeedback.selectionClick();
    _sfx.play('coin');
    setState(() {
      _flying = false;
      _wallet = 1;
      _walletBump = true;
    });
    await _wait(250);
    if (!_live(id)) return;
    setState(() {
      _walletBump = false;
      _zoom = false;
    });
    await _wait(400);
    // Toute la communauté like : le compteur et les pièces s'envolent
    await _countUp(id, first.likesFrom + 1.0, first.likes.toDouble(), 1900, (v) {
      _likes1 = v;
      _wallet = (v - first.likesFrom).round();
    });
    if (!_live(id)) return;
    _sfx.play('coin');
    await _wait(700);
    if (!_live(id)) return;

    // ── 2. Les posts travaillent (la même carte continue) ──────────────────────
    setState(() {
      _scene = 1;
      _postIndex = 0;
      _pLikes = first.likes.toDouble();
      _pViews = 0;
      _runCoins = first.likes.toDouble();
      _runFcfa = first.fcfa(first.likes.toDouble(), 0);
    });
    await _wait(600);
    for (var i = 0; i < _demo.length; i++) {
      if (!_live(id)) return;
      final p = _demo[i];
      if (i > 0) {
        _sfx.play('whoosh', volume: 0.45);
        setState(() {
          _postIndex = i;
          _pLikes = 0;
          _pViews = 0;
        });
        await _wait(550);
      }
      final baseCoins = _runCoins - (i == 0 ? p.likes : 0), baseFcfa = _runFcfa - (i == 0 ? p.fcfa(p.likes.toDouble(), 0) : 0);
      final likesFrom = i == 0 ? p.likes.toDouble() : 0.0;
      await _countUp(id, 0, 1, 1600, (t) {
        _pLikes = likesFrom + (p.likes - likesFrom) * t;
        _pViews = p.views * t;
        _runCoins = baseCoins + _pLikes;
        _runFcfa = baseFcfa + p.fcfa(_pLikes, _pViews);
      });
      if (!_live(id)) return;
      HapticFeedback.selectionClick();
      _sfx.play('coin');
      await _wait(750);
    }
    if (!_live(id)) return;

    // ── 3. La barre du total monte au centre et devient le grand montant ───────
    _sfx.play('rise', volume: 0.5);
    setState(() {
      _scene = 2;
      _total = _runFcfa;
    });
    await _wait(1300);
    if (!_live(id)) return;
    HapticFeedback.mediumImpact();
    _sfx.play('coin');
    setState(() => _claimReady = true);
    if (_kVideoMode) {
      await _wait(2200);
      if (_live(id)) _claim();
    }
  }

  /// Relance la lecture depuis le début.
  void _restart() {
    _runId++;
    _fly.reset();
    _heartBounce.reset();
    _burst.reset();
    _confetti.reset();
    setState(() {
      _scene = 0;
      _cardIn = false;
      _liked = false;
      _zoom = false;
      _tapRing = false;
      _walletBump = false;
      _flying = false;
      _likes1 = _posts[0].likesFrom.toDouble();
      _wallet = 0;
      _postIndex = 0;
      _pLikes = 0;
      _pViews = 0;
      _runCoins = 0;
      _runFcfa = 0;
      _total = 0;
      _claimReady = false;
    });
    _run();
  }

  void _claim() {
    HapticFeedback.heavyImpact();
    _sfx.play('success');
    setState(() => _scene = 3);
    _confetti.forward(from: 0);
  }

  void _finish({required bool signup}) {
    final nav = Navigator.of(context);
    if (widget.inApp) {
      nav.pop();
      if (signup) nav.pushNamed('/user_posts_form');
      return;
    }
    nav.pushReplacement(MaterialPageRoute(builder: (_) => LoginPageUser()));
    if (signup) nav.push(MaterialPageRoute(builder: (_) => const EulaScreen()));
  }

  // ── Mise en forme ────────────────────────────────────────────────────────────
  String _n(num v) {
    final s = v.round().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
      b.write(s[i]);
    }
    return b.toString();
  }

  String _k(num v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1).replaceAll('.', ',')}M';
    if (v >= 10000) return '${(v / 1000).toStringAsFixed(1).replaceAll('.', ',')}k';
    return _n(v);
  }

  // Durées et courbe communes : tout bouge ensemble, comme un seul plan
  static const _move = Duration(milliseconds: 950);
  static const _curve = Curves.easeInOutCubic;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050807),
      body: Stack(
        key: _stageKey,
        fit: StackFit.expand,
        children: [
          _aurora(),
          SafeArea(
            child: Column(
              children: [
                _topBar(),
                Expanded(child: _stage()),
              ],
            ),
          ),
          if (_flying) _flyingCoin(),
          if (_scene == 3) IgnorePointer(child: _confettiLayer()),
        ],
      ),
    );
  }

  /// Toute la scène sur une seule surface : les éléments glissent, grandissent
  /// et se fondent d'un état à l'autre, sans changement de page.
  Widget _stage() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Titre : le texte se remplace en glissant vers le haut
        Positioned(
          top: 14,
          left: 0,
          right: 0,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 700),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder: (cur, prev) => Stack(alignment: Alignment.topCenter, children: [...prev, if (cur != null) cur]),
            transitionBuilder: (child, a) => FadeTransition(
              opacity: a,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, 0.35), end: Offset.zero).animate(a),
                child: child,
              ),
            ),
            child: KeyedSubtree(key: ValueKey('h$_scene'), child: _headlineFor(_scene)),
          ),
        ),

        // Carte du post : reste en place du like aux compteurs, puis s'éloigne
        Positioned(
          top: 104,
          left: 0,
          right: 0,
          child: AnimatedOpacity(
            opacity: _cardIn && _scene <= 1 ? 1 : 0,
            duration: Duration(milliseconds: _scene >= 2 ? 380 : 700),
            curve: _curve,
            child: AnimatedSlide(
              offset: !_cardIn ? const Offset(0, 0.12) : (_scene >= 2 ? const Offset(0, -0.18) : Offset.zero),
              duration: _move,
              curve: _curve,
              child: AnimatedScale(
                scale: _scene >= 2 ? 0.82 : 1,
                duration: _move,
                curve: _curve,
                child: _cardGroup(),
              ),
            ),
          ),
        ),

        // Barre du total → grand montant central → montant du trophée
        AnimatedAlign(
          alignment: _scene <= 1 ? const Alignment(0, 0.9) : (_scene == 2 ? const Alignment(0, -0.32) : const Alignment(0, -0.4)),
          duration: const Duration(milliseconds: 1100),
          curve: _curve,
          child: AnimatedOpacity(
            opacity: _scene >= 1 ? 1 : 0,
            duration: const Duration(milliseconds: 600),
            child: AnimatedScale(
              scale: _scene == 3 ? 0.82 : 1,
              duration: _move,
              curve: _curve,
              child: _totalBox(),
            ),
          ),
        ),

        // Moyens de retrait et bouton « Récupérer mes gains »
        Positioned(
          left: 24,
          right: 24,
          bottom: 30,
          child: IgnorePointer(
            ignoring: _scene != 2,
            child: AnimatedOpacity(
              opacity: _scene == 2 ? 1 : 0,
              duration: const Duration(milliseconds: 700),
              curve: _curve,
              child: AnimatedSlide(
                offset: _scene == 2 ? Offset.zero : const Offset(0, 0.25),
                duration: _move,
                curve: _curve,
                child: _claimBlock(),
              ),
            ),
          ),
        ),

        // Félicitations et invitation
        Positioned(
          left: 26,
          right: 26,
          bottom: 18,
          child: IgnorePointer(
            ignoring: _scene != 3,
            child: AnimatedOpacity(
              opacity: _scene == 3 ? 1 : 0,
              duration: const Duration(milliseconds: 800),
              curve: _curve,
              child: AnimatedSlide(
                offset: _scene == 3 ? Offset.zero : const Offset(0, 0.2),
                duration: _move,
                curve: _curve,
                child: _bravoBlock(),
              ),
            ),
          ),
        ),

        // Mention « exemple »
        Positioned(
          left: 0,
          right: 0,
          bottom: 6,
          child: AnimatedOpacity(
            opacity: _scene == 1 ? 1 : 0,
            duration: const Duration(milliseconds: 500),
            child: Center(
              child: Text(context.tr('Exemple de gains, à titre indicatif'),
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _headlineFor(int scene) {
    switch (scene) {
      case 0:
        return _headline(context.tr('Sur Afrolook, chaque like '), context.tr('paie'), context.tr(' le créateur.'));
      case 2:
        return const SizedBox(width: double.infinity);
      case 1:
        return _headline(context.tr('Tes posts '), context.tr('travaillent'), context.tr(' pour toi, jour et nuit.'),
            size: 25);
      default:
        return _headline('', context.tr('Félicitations !'), '', size: 32);
    }
  }

  // Fond : deux halos lumineux qui dérivent lentement (vert et or)
  Widget _aurora() {
    return AnimatedBuilder(
      animation: _bg,
      builder: (_, __) {
        final t = _bg.value * 2 * math.pi;
        return Stack(fit: StackFit.expand, children: [
          Align(
            alignment: Alignment(-0.8 + 0.3 * math.sin(t), -0.7 + 0.2 * math.cos(t)),
            child: _halo(const Color(0xFF1FAA59), 420),
          ),
          Align(
            alignment: Alignment(0.9 + 0.2 * math.cos(t * 1.3), 0.6 + 0.25 * math.sin(t)),
            child: _halo(_gold, 380),
          ),
        ]);
      },
    );
  }

  Widget _halo(Color c, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [c.withOpacity(0.22), c.withOpacity(0.0)]),
        ),
      );

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
      child: Row(
        children: [
          // Progression des 4 étapes
          ...List.generate(4, (i) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              curve: _curve,
              margin: const EdgeInsets.only(right: 5),
              width: i == _scene ? 22 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: i <= _scene ? _gold : Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
          const Spacer(),
          AnimatedOpacity(
            opacity: _cardIn && _scene == 0 ? 1 : 0,
            duration: const Duration(milliseconds: 500),
            child: _walletPill(),
          ),
          if (!_kVideoMode) IconButton(
            tooltip: context.tr('Revoir'),
            visualDensity: VisualDensity.compact,
            onPressed: _restart,
            icon: const Icon(Icons.replay_rounded, color: Colors.white60, size: 22),
          ),
          AnimatedOpacity(
            opacity: _scene < 3 && !_kVideoMode ? 1 : 0,
            duration: const Duration(milliseconds: 400),
            child: TextButton(
              onPressed: _scene < 3 ? () => _finish(signup: false) : null,
              child: Text(context.tr('Passer'), style: const TextStyle(color: Colors.white60, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _walletPill() {
    return AnimatedScale(
      scale: _walletBump ? 1.18 : 1,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      child: Container(
        key: _walletKey,
        margin: const EdgeInsets.only(right: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2410),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _gold.withOpacity(0.5)),
        ),
        child: Text('🪙 ${_n(_wallet)}',
            style: const TextStyle(
                color: _gold, fontWeight: FontWeight.w800, fontSize: 14, fontFeatures: [FontFeature.tabularFigures()])),
      ),
    );
  }

  Widget _headline(String a, String gold, String b, {double size = 27}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text.rich(
        textAlign: TextAlign.center,
        TextSpan(
          style: TextStyle(color: Colors.white, fontSize: size, fontWeight: FontWeight.w800, height: 1.18, letterSpacing: -0.4),
          children: [
            TextSpan(text: a),
            TextSpan(text: gold, style: const TextStyle(color: _gold)),
            TextSpan(text: b),
          ],
        ),
      ),
    );
  }

  /// Carte courante + bandeau « ce post a rapporté ».
  Widget _cardGroup() {
    final p = _demo[_postIndex];
    final inLike = _scene == 0;
    final likes = inLike ? _likes1 : _pLikes;
    final fcfa = p.fcfa(_pLikes, _pViews);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 650),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          layoutBuilder: (cur, prev) => Stack(alignment: Alignment.topCenter, children: [...prev, if (cur != null) cur]),
          transitionBuilder: (child, a) {
            final incoming = child.key == ValueKey(_postIndex);
            return SlideTransition(
              position: Tween(begin: Offset(incoming ? 1.1 : -1.1, 0), end: Offset.zero).animate(a),
              child: child,
            );
          },
          child: KeyedSubtree(
            key: ValueKey(_postIndex),
            child: AnimatedScale(
              // Zoom « caméra » sur le bouton like
              scale: _zoom && inLike ? 1.22 : 1,
              alignment: const Alignment(-0.5, -1.0),
              duration: const Duration(milliseconds: 750),
              curve: _curve,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: _FeedCard(
                  post: p,
                  likes: likes.round(),
                  liked: _postIndex > 0 || _liked,
                  heartKey: _postIndex == 0 ? _heartKey : null,
                  heartBounce: _postIndex == 0 ? _heartBounce : null,
                  burst: _postIndex == 0 ? _burst : null,
                  tapRing: _tapRing && inLike,
                  interactions: (likes + p.comments + p.reposts).round(),
                  colors: _colors,
                  compact: true,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Sous-titre de la scène du like, remplacé par le bandeau des gains
        SizedBox(
          height: 46,
          child: Stack(alignment: Alignment.center, children: [
            AnimatedOpacity(
              opacity: inLike && _wallet > 1 ? 1 : 0,
              duration: const Duration(milliseconds: 500),
              child: Text(context.tr('+1 pièce pour le créateur à chaque like'),
                  textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 15)),
            ),
            AnimatedOpacity(
              opacity: _scene >= 1 ? 1 : 0,
              duration: const Duration(milliseconds: 600),
              child: AnimatedSlide(
                offset: _scene >= 1 ? Offset.zero : const Offset(0, 0.4),
                duration: _move,
                curve: _curve,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: PostCoins.bg(_colors),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: PostCoins.border.withOpacity(0.6)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.visibility_outlined, size: 16, color: PostCoins.fg(_colors)),
                      const SizedBox(width: 5),
                      Text(context.tr('{a} vues', {'a': _k(_pViews)}),
                          style: TextStyle(color: PostCoins.fg(_colors), fontSize: 13, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text('🪙 ${_n(_pLikes)}',
                          style: TextStyle(color: PostCoins.fg(_colors), fontSize: 14, fontWeight: FontWeight.w800)),
                      const SizedBox(width: 8),
                      Text(Money.approx(fcfa),
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
            ),
          ]),
        ),
      ],
    );
  }

  /// Une seule boîte qui passe de la barre « Ce mois-ci » au grand montant.
  Widget _totalBox() {
    final big = _scene >= 2;
    final views = _demo.fold<int>(0, (s, p) => s + p.views);
    return AnimatedContainer(
      duration: _move,
      curve: _curve,
      margin: EdgeInsets.symmetric(horizontal: big ? 24 : 16),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: big ? 22 : 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(big ? 0.0 : 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: big ? Colors.transparent : Colors.white12),
      ),
      child: AnimatedSize(
        duration: _move,
        curve: _curve,
        child: AnimatedCrossFade(
          duration: const Duration(milliseconds: 600),
          sizeCurve: _curve,
          crossFadeState: big ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: Row(
            children: [
              Text(context.tr('Ce mois-ci'), style: const TextStyle(color: Colors.white70, fontSize: 14)),
              const Spacer(),
              Text('🪙 ${_n(_runCoins)}', style: const TextStyle(color: _gold, fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(width: 10),
              Text(Money.fmt(_runFcfa),
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
            ],
          ),
          secondChild: SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                AnimatedSize(
                  duration: _move,
                  curve: _curve,
                  child: _scene == 3
                      ? const Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: Text('🏆', style: TextStyle(fontSize: 56)),
                        )
                      : const SizedBox(width: double.infinity),
                ),
                Text(context.tr('Ce mois-ci, tes posts t\'ont rapporté'),
                    textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 17)),
                const SizedBox(height: 8),
                FittedBox(
                  child: Text(Money.fmt(_total),
                      style: const TextStyle(
                          color: _gold,
                          fontSize: 64,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.5,
                          fontFeatures: [FontFeature.tabularFigures()])),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr('{a} pièces de likes + les revenus de {b} vues', {'a': _n(_runCoins), 'b': _n(views)}),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white60, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _claimBlock() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!kIsAppleStore) ...[
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              _chip(Icons.phone_iphone_rounded, context.tr('Mobile Money')),
              _chip(Icons.credit_card_rounded, context.tr('Carte bancaire')),
            ],
          ),
          const SizedBox(height: 10),
          Text(context.tr('Demande ton retrait quand tu veux.'),
              style: const TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 22),
        ],
        AnimatedOpacity(
          opacity: _claimReady ? 1 : 0.0,
          duration: const Duration(milliseconds: 500),
          child: SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton(
              onPressed: _claimReady ? _claim : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                disabledBackgroundColor: _gold,
                foregroundColor: const Color(0xFF3A2A00),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 0,
              ),
              child: Text(kIsAppleStore ? context.tr('Voir mes gains') : context.tr('Récupérer mes gains'),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF3A2A00))),
            ),
          )
              .animate(onPlay: (c) => c.repeat())
              .shimmer(duration: 1800.ms, color: Colors.white.withOpacity(0.55))
              .scaleXY(begin: 1, end: 1.03, duration: 900.ms, curve: Curves.easeInOut)
              .then()
              .scaleXY(begin: 1.03, end: 1, duration: 900.ms, curve: Curves.easeInOut),
        ),
        const SizedBox(height: 10),
        Text(context.tr('Exemple de gains, à titre indicatif'),
            style: const TextStyle(color: Colors.white38, fontSize: 11)),
      ],
    );
  }

  Widget _chip(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 17, color: Colors.white),
          const SizedBox(width: 7),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _bravoBlock() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.tr('Toi aussi, tu peux obtenir ces résultats en devenant créateur sur Afrolook.'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 18, height: 1.4, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Text(
          context.tr('Crée ton premier post et profite de la monétisation dès aujourd\'hui.'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white60, fontSize: 15, height: 1.4),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 58,
          child: ElevatedButton(
            onPressed: () => _finish(signup: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2ECC71),
              foregroundColor: const Color(0xFF06331A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              elevation: 0,
            ),
            child: Text(widget.inApp ? context.tr('Créer un post') : context.tr('Créer mon compte et publier'),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () => _finish(signup: false),
              child: Text(widget.inApp ? context.tr('Plus tard') : context.tr('J\'ai déjà un compte'),
                  style: const TextStyle(color: Colors.white70, fontSize: 15)),
            ),
            TextButton.icon(
              onPressed: _restart,
              icon: const Icon(Icons.replay_rounded, color: Colors.white54, size: 18),
              label: Text(context.tr('Revoir'), style: const TextStyle(color: Colors.white54, fontSize: 14)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _flyingCoin() {
    return AnimatedBuilder(
      animation: _fly,
      builder: (_, __) {
        final t = Curves.easeInOutCubic.transform(_fly.value);
        // Trajectoire en arc (courbe de Bézier quadratique)
        final ctrl = Offset((_flyFrom.dx + _flyTo.dx) / 2 - 60, math.min(_flyFrom.dy, _flyTo.dy) - 140);
        final p = Offset(
          (1 - t) * (1 - t) * _flyFrom.dx + 2 * (1 - t) * t * ctrl.dx + t * t * _flyTo.dx,
          (1 - t) * (1 - t) * _flyFrom.dy + 2 * (1 - t) * t * ctrl.dy + t * t * _flyTo.dy,
        );
        final scale = 1.4 - 0.6 * t;
        return Positioned(
          left: p.dx - 30,
          top: p.dy - 18,
          child: Transform.scale(
            scale: scale,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: _gold, borderRadius: BorderRadius.circular(14)),
              child: const Text('+1 🪙',
                  style: TextStyle(color: Color(0xFF412402), fontWeight: FontWeight.w900, fontSize: 14)),
            ),
          ),
        );
      },
    );
  }

  Widget _confettiLayer() => AnimatedBuilder(
        animation: _confetti,
        builder: (_, __) => CustomPaint(painter: _ConfettiPainter(_confetti.value)),
      );
}

// ── Carte de post, reproduction de la carte du feed ──────────────────────────
class _FeedCard extends StatelessWidget {
  final _DemoPost post;
  final int likes, interactions;
  final bool liked, tapRing, compact;
  final GlobalKey? heartKey;
  final AnimationController? heartBounce, burst;
  final AppColors colors;

  const _FeedCard({
    required this.post,
    required this.likes,
    required this.liked,
    required this.interactions,
    required this.colors,
    this.heartKey,
    this.heartBounce,
    this.burst,
    this.tapRing = false,
    this.compact = false,
  });

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Container(
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 18, backgroundColor: c.primary, backgroundImage: AssetImage(post.image)),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Flexible(
                          child: PseudoTag(label: '@${post.pseudo}',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold, fontSize: 13.5)),
                        ),
                        const SizedBox(width: 3),
                        Icon(Icons.verified, size: 13, color: c.info),
                      ]),
                      Text(context.tr('{a} abonnés', {'a': post.followers}),
                          style: TextStyle(color: c.textSecondary, fontSize: 11)),
                    ]),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(16)),
                    child: Text(context.tr('Suivre'),
                        style: TextStyle(color: c.onPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                  // Drapeau du pays (masqué dans le rendu vidéo : pas d'emoji drapeau hors appareil)
                  if (!_kVideoMode) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withOpacity(0.12), width: 0.8),
                      ),
                      child: Text('${post.flag} ', style: const TextStyle(fontSize: 11)),
                    ),
                  ],
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.more_horiz, color: c.textSecondary, size: 20),
                  ),
                ]),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(children: [
                    for (final w in post.text.split(' '))
                      TextSpan(text: '$w ', style: TextStyle(color: w.startsWith('#') ? c.info : c.textPrimary)),
                  ]),
                  style: const TextStyle(fontSize: 15, height: 1.4),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.textSecondary.withOpacity(0.18), width: 0.8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: compact ? math.max(post.aspect, 1.05) : post.aspect,
                      child: Image.asset(post.image, fit: BoxFit.cover),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // Barre d'actions : réduite si l'écran est étroit, jamais de débordement
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 345,
                    child: Row(children: [
                  _action(FontAwesome.comment_o, post.comments, c.textSecondary),
                  _heart(c),
                  _action(Icons.repeat, post.reposts, c.textSecondary),
                  const SizedBox(width: 4),
                  _giftPill(context, c),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withOpacity(0.09), width: 0.8),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.bar_chart_rounded, size: 13, color: c.textSecondary),
                      const SizedBox(width: 3),
                      Text(_fmt(interactions),
                          style: TextStyle(color: c.textSecondary, fontSize: 11, fontWeight: FontWeight.w500)),
                    ]),
                  ),
                ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Pastille « Cadeau » + bulle d'envoi rapide, comme CadeauBadge
  Widget _giftPill(BuildContext context, AppColors c) {
    const pillBg = Color(0xFF1E1E1E);
    final pillBorder = const Color(0xFFFF6A00).withOpacity(0.35);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: pillBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: pillBorder, width: 0.8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 16,
            height: 16,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [Color(0xFFFF4500), Color(0xFFFFAA00)]),
            ),
            child: const Center(child: Text('🏆', style: TextStyle(fontSize: 9))),
          ),
          const SizedBox(width: 4),
          Text(context.tr('Cadeau'), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
          Container(width: 1, height: 10, margin: const EdgeInsets.symmetric(horizontal: 5), color: pillBorder),
          Text(_fmt(post.gifts), style: TextStyle(color: c.textSecondary, fontSize: 10, fontWeight: FontWeight.w500)),
        ]),
      ),
      const SizedBox(width: 5),
      Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(shape: BoxShape.circle, color: pillBg, border: Border.all(color: pillBorder, width: 0.8)),
        child: const Center(child: Text('❤️', style: TextStyle(fontSize: 14))),
      ),
    ]);
  }

  Widget _action(IconData icon, int count, Color color) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(children: [
          Icon(icon, size: 18, color: color),
          Text(_fmt(count), style: TextStyle(color: color, fontSize: 13)),
        ]),
      );

  Widget _heart(AppColors c) {
    final color = liked ? c.danger : c.textSecondary;
    Widget heart = LikeCoinHeart(icon: liked ? FontAwesome.heart : FontAwesome.heart_o, color: color, size: 20);
    if (heartBounce != null) {
      heart = AnimatedBuilder(
        animation: heartBounce!,
        builder: (_, child) {
          final t = heartBounce!.value;
          final s = t == 0
              ? 1.0
              : TweenSequence([
                  TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.7), weight: 35),
                  TweenSequenceItem(tween: Tween(begin: 1.7, end: 0.9), weight: 30),
                  TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 35),
                ]).transform(t);
          return Transform.scale(scale: s, child: child);
        },
        child: heart,
      );
    }
    return Padding(
      key: heartKey,
      padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 5),
      child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
        if (tapRing)
          Positioned(
            left: -14,
            top: -14,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white70, width: 2)),
            ).animate().scale(begin: const Offset(0.4, 0.4), end: const Offset(1.2, 1.2), duration: 350.ms).fadeOut(duration: 350.ms),
          ),
        if (burst != null)
          Positioned(
            left: -30,
            top: -30,
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: burst!,
                builder: (_, __) => CustomPaint(size: const Size(80, 80), painter: _BurstPainter(burst!.value)),
              ),
            ),
          ),
        Column(children: [
          heart,
          Text(_fmt(likes), style: TextStyle(color: color, fontSize: 13, fontFeatures: const [FontFeature.tabularFigures()])),
        ]),
      ]),
    );
  }
}

/// Éclats autour du cœur au moment du like.
class _BurstPainter extends CustomPainter {
  final double t;
  _BurstPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final center = Offset(size.width / 2 - 6, size.height / 2 - 8);
    const colors = [Color(0xFFFF4D6D), Color(0xFFF5C542), Color(0xFFFF8FA3), Color(0xFF2ECC71)];
    final e = Curves.easeOutCubic.transform(t);
    for (var i = 0; i < 10; i++) {
      final a = i / 10 * 2 * math.pi;
      final r = 8 + 30 * e;
      final p = center + Offset(math.cos(a), math.sin(a)) * r;
      canvas.drawCircle(p, 3.2 * (1 - t), Paint()..color = colors[i % 4].withOpacity(1 - t));
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}

/// Confettis de la scène finale.
class _ConfettiPainter extends CustomPainter {
  final double t;
  _ConfettiPainter(this.t);
  static final _rand = math.Random(7);
  static final _pieces = List.generate(
      90,
      (i) => [
            _rand.nextDouble(), // x
            _rand.nextDouble() * 0.35, // délai
            0.6 + _rand.nextDouble() * 0.7, // vitesse
            _rand.nextDouble() * 2 * math.pi, // rotation
            (i % 5).toDouble(), // couleur
          ]);

  @override
  void paint(Canvas canvas, Size size) {
    const colors = [Color(0xFFF5C542), Color(0xFF2ECC71), Color(0xFFFF4D6D), Color(0xFF7F77DD), Colors.white];
    for (final p in _pieces) {
      final lt = ((t - p[1]) / (1 - p[1])).clamp(0.0, 1.0);
      if (lt <= 0) continue;
      final x = p[0] * size.width + math.sin(lt * 6 + p[3]) * 18;
      final y = -20 + lt * p[2] * (size.height + 60);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p[3] + lt * 8);
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(-4, -6, 8, 12), const Radius.circular(2)),
        Paint()..color = colors[p[4].toInt()].withOpacity(lt > 0.85 ? (1 - lt) / 0.15 : 1),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

// ── Rappel dans le feed ───────────────────────────────────────────────────────
/// Fréquence : au plus une fois tous les 3 jours par feed, une fois par session.
class MonetizationReminder {
  /// Vrai tant que les 5 tutoriels du jour n'ont pas tous été montrés (voir [TutoRotation]).
  static Future<bool> due(String feed) async => (await TutoRotation.remainingToday()) > 0;

  static Future<void> markShown(String feed) async {}
}

/// Carte animée insérée dans le feed : un post, le like, la pièce qui monte,
/// et le rappel « chaque like paie le créateur ». [fullScreen] pour le feed vidéo.
class _LikeSceneReminder extends StatefulWidget {
  final String feed;
  final bool fullScreen;
  const _LikeSceneReminder({super.key, required this.feed, this.fullScreen = false});

  @override
  State<_LikeSceneReminder> createState() => _FeedMonetizationReminderState();
}

class _FeedMonetizationReminderState extends State<_LikeSceneReminder> with TickerProviderStateMixin {
  static const _gold = Color(0xFFF5C542);
  late final AnimationController _heartBounce =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  late final AnimationController _burst = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  late final AnimationController _loop = AnimationController(vsync: this, duration: const Duration(milliseconds: 5200));
  bool _hidden = false;

  static const _post = _DemoPost('assets/images/intro3.jpg', 'nadia.vibes', '12,4k',
      'Ma routine selfie du matin ☀️ #afrostyle', 247, 3200, 41000, 318, 42, 16, 16 / 9, '🇨🇮');

  @override
  void initState() {
    super.initState();
    MonetizationReminder.markShown(widget.feed);
    _loop.addListener(() {
      // Le like tombe à 25 % de la boucle
      if (_loop.value >= 0.25 && _heartBounce.status == AnimationStatus.dismissed) {
        _heartBounce.forward(from: 0);
        _burst.forward(from: 0);
      }
      if (mounted) setState(() {});
    });
    _loop.addStatusListener((st) {
      if (st == AnimationStatus.completed && mounted) {
        _heartBounce.reset();
        _loop.forward(from: 0);
      }
    });
    _loop.forward();
  }

  @override
  void dispose() {
    _heartBounce.dispose();
    _burst.dispose();
    _loop.dispose();
    super.dispose();
  }

  String _n(num v) {
    final s = v.round().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
      b.write(s[i]);
    }
    return b.toString();
  }

  void _openTutorial() {
    Navigator.of(context).push(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (_, __, ___) => const MonetizationTutorialPage(inApp: true),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_hidden) return const SizedBox.shrink();
    final ac = AppColors.of(context);
    final gold = ac.isDark ? _gold : const Color(0xFF8A5A00);
    final t = _loop.value;
    final liked = t >= 0.25;
    // Après le like, les likes et les pièces montent jusqu'à 3 200
    final grow = Curves.easeOutCubic.transform(((t - 0.32) / 0.5).clamp(0.0, 1.0));
    final likes = liked ? 248 + (_post.likes - 248) * grow : 247.0;
    final coins = liked ? 1 + (_post.likes - 248) * grow : 0.0;
    final fcfa = coins * _fcfaPerCoin;
    final coinFly = ((t - 0.27) / 0.18).clamp(0.0, 1.0);

    final content = Column(
      mainAxisSize: widget.fullScreen ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: gold.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
            child: Text(context.tr('Le savais-tu ?'),
                style: TextStyle(color: gold, fontSize: 12, fontWeight: FontWeight.w800)),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: ac.isDark ? const Color(0xFF2A2410) : const Color(0xFFFFF4D6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: gold.withOpacity(0.5)),
            ),
            child: Text('🪙 ${_n(coins)}  ${Money.approx(fcfa)}',
                style: TextStyle(color: gold, fontSize: 12.5, fontWeight: FontWeight.w800)),
          ),
          if (!widget.fullScreen)
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() => _hidden = true),
              icon: Icon(Icons.close_rounded, color: ac.textSecondary, size: 20),
            ),
        ]),
        const SizedBox(height: 12),
        Text.rich(
          TextSpan(children: [
            TextSpan(text: context.tr('Sur Afrolook, chaque like ')),
            TextSpan(text: context.tr('paie'), style: TextStyle(color: gold)),
            TextSpan(text: context.tr(' le créateur.')),
          ]),
          textAlign: TextAlign.center,
          style: TextStyle(
              color: ac.textPrimary, fontSize: widget.fullScreen ? 26 : 20, fontWeight: FontWeight.w800, height: 1.2),
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: _openTutorial,
          child: Stack(clipBehavior: Clip.none, children: [
            _FeedCard(
              post: _post,
              likes: likes.round(),
              liked: liked,
              heartBounce: _heartBounce,
              burst: _burst,
              interactions: (likes + _post.comments + _post.reposts).round(),
              colors: ac,
            ),
            if (coinFly > 0 && coinFly < 1)
              Positioned(
                left: 70 + 160 * coinFly,
                bottom: 40 + 220 * Curves.easeOut.transform(coinFly),
                child: Opacity(
                  opacity: 1 - coinFly * 0.6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(color: _gold, borderRadius: BorderRadius.circular(12)),
                    child: const Text('+1 🪙',
                        style: TextStyle(color: Color(0xFF412402), fontWeight: FontWeight.w900, fontSize: 13)),
                  ),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 14),
        Text(
          context.tr('Publie, reçois des likes : chaque like te rapporte 1 pièce, convertible en argent.'),
          textAlign: TextAlign.center,
          style: TextStyle(color: ac.textSecondary, fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _openTutorial,
              style: OutlinedButton.styleFrom(
                foregroundColor: ac.textPrimary,
                side: BorderSide(color: ac.border),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(context.tr('Voir l\'animation'), style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pushNamed('/user_posts_form'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2ECC71),
                foregroundColor: const Color(0xFF06331A),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(context.tr('Créer un post'), style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
        TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TutoListPage())),
          child: Text(context.tr('Voir plus de tutoriels'), style: TextStyle(color: ac.textSecondary)),
        ),
        if (widget.fullScreen) ...[
          const SizedBox(height: 18),
          Text(context.tr('Glisse vers le haut pour continuer'),
              style: TextStyle(color: ac.textSecondary, fontSize: 12)),
        ],
      ],
    );

    return Container(
      margin: widget.fullScreen ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      padding: EdgeInsets.fromLTRB(16, widget.fullScreen ? 60 : 14, 16, widget.fullScreen ? 30 : 16),
      decoration: BoxDecoration(
        borderRadius: widget.fullScreen ? null : BorderRadius.circular(22),
        border: widget.fullScreen ? null : Border.all(color: gold.withOpacity(0.25)),
        gradient: RadialGradient(
          center: const Alignment(-0.8, -0.9),
          radius: 1.3,
          colors: [ac.isDark ? const Color(0x331FAA59) : const Color(0x261FAA59), ac.isDark ? const Color(0xFF070B09) : ac.background],
        ),
      ),
      child: content,
    );
  }
}

/// Rendu vidéo (outil interne) : branche un récepteur des sons du tutoriel.
void setMonetizationTutorialSfxHook(void Function(String name, double volume)? hook) => _Sfx.hook = hook;


/// Rappel de rémunération inséré dans les feeds : à chaque affichage la scène change
/// (animation « like » historique, puis les scènes du catalogue `tuto_catalog.dart`).
class FeedMonetizationReminder extends StatefulWidget {
  final String feed;
  final bool fullScreen;
  const FeedMonetizationReminder({super.key, required this.feed, this.fullScreen = false});

  @override
  State<FeedMonetizationReminder> createState() => _RotatingReminderState();
}

class _RotatingReminderState extends State<FeedMonetizationReminder> {
  bool _ready = false;
  TutoScene? _scene; // null → « Tutoriel de monétisation » d'origine (animation du like)
  bool _none = false;
  bool _hidden = false;

  @override
  void initState() {
    super.initState();
    TutoRotation.takeToday().then((pick) {
      if (!mounted) return;
      setState(() {
        _none = pick == null;
        _scene = pick?.scene;
        _ready = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready || _hidden || _none) return const SizedBox.shrink();
    final s = _scene;
    if (s == null) return _LikeSceneReminder(feed: widget.feed, fullScreen: widget.fullScreen);
    return TutoSceneCard(
      scene: s,
      fullScreen: widget.fullScreen,
      onClose: widget.fullScreen ? null : () => setState(() => _hidden = true),
      onSeeAll: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TutoListPage())),
    );
  }
}
