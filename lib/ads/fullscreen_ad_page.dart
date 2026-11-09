import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import 'ad_banner.dart';

/// Page de pub en plein écran (lecteur vertical, chroniques) : jamais de page noire, jamais d'attente sans fin.
///
/// Ordre convenu partout dans l'application :
///  1. la pub du RÉSEAU (Appodeal puis AdMob) est chargée en coulisses, avant d'être montrée ; dès qu'elle est prête, elle s'affiche avec son décompte ;
///  2. si elle n'est pas prête au bout de [waitMs] (ou si le réseau échoue), la pub d'Afrolook Ads prend la place ([ownBuilder]) ;
///  3. s'il n'y a ni l'une ni l'autre, la page se passe toute seule ([onNext]) : on ne montre jamais une page vide.
/// Une pub affichée dure [networkSeconds] (réseau) ou [ownSeconds] (Afrolook Ads : 3 s pour une image, 5 s pour une vidéo), puis [onNext] est appelé ; on peut aussi
/// passer en glissant. Rien ne démarre tant que la page n'est pas celle qu'on regarde ([active]) ; le chargement, lui, commence dès que la page est construite.
class FullScreenAdPage extends StatefulWidget {
  const FullScreenAdPage({
    super.key,
    required this.active,
    required this.onNext,
    this.ownBuilder,
    this.networkBuilder,
    this.waitMs = 3000,
    this.networkSeconds = 5,
    this.ownSeconds = 5,
    this.showCountdown = true,
    this.onShown,
    this.retryNext = false,
  });

  /// Redemander [onNext] (jusqu'à 6 fois, toutes les 0,7 s) tant que la page est toujours regardée : pour les défilements où un premier appel peut échouer.
  final bool retryNext;

  /// Cette page est celle qu'on regarde (les timers ne tournent que dans ce cas).
  final bool active;

  /// Passer à la suite (fin du décompte, ou aucune pub à montrer).
  final VoidCallback onNext;

  /// Pub Afrolook Ads de repli ; reçoit un rappel à appeler quand elle est finie. Null : aucune pub de repli.
  final Widget Function(VoidCallback onComplete)? ownBuilder;

  /// Pub du réseau ; reçoit les rappels « chargée » et « échec ». Par défaut : grand format Appodeal / AdMob.
  final Widget Function(VoidCallback onLoaded, VoidCallback onFailed)? networkBuilder;

  /// Temps laissé à la pub du réseau pour être prête une fois la page regardée.
  final int waitMs;
  final int networkSeconds;
  final int ownSeconds;

  /// Montrer la pastille « Suivant dans N s » (faux quand l'écran a déjà sa propre barre de progression).
  final bool showCountdown;

  /// Une pub vient d'être montrée pour [seconds] secondes (l'écran peut régler sa barre de progression).
  final void Function(int seconds)? onShown;

  @override
  State<FullScreenAdPage> createState() => _FullScreenAdPageState();
}

enum _Phase { loading, network, own, skipped }

class _FullScreenAdPageState extends State<FullScreenAdPage> {
  _Phase _phase = _Phase.loading;
  bool _netLoaded = false;
  bool _netFailed = false;
  bool _advanced = false;
  int _left = 0;
  Timer? _wait;
  Timer? _tick;
  Timer? _retryNext;

  @override
  void initState() {
    super.initState();
    if (widget.active) _onActive();
  }

  @override
  void didUpdateWidget(FullScreenAdPage old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      _onActive();
    } else if (!widget.active && old.active) {
      _wait?.cancel();
      _tick?.cancel();
      _retryNext?.cancel();
    }
  }

  @override
  void dispose() {
    _wait?.cancel();
    _tick?.cancel();
    _retryNext?.cancel();
    super.dispose();
  }

  /// La page vient d'être regardée : on montre ce qui est prêt, sinon on laisse un court délai au réseau.
  void _onActive() {
    if (_phase == _Phase.network || _phase == _Phase.own) {
      _startCountdown(_phase == _Phase.network ? widget.networkSeconds : widget.ownSeconds, restart: false);
      return;
    }
    if (_phase != _Phase.loading) return;
    if (_netLoaded) return _show(_Phase.network);
    if (_netFailed) return _fallback();
    _wait?.cancel();
    _wait = Timer(Duration(milliseconds: widget.waitMs), () {
      if (!mounted || _phase != _Phase.loading) return;
      _netLoaded ? _show(_Phase.network) : _fallback();
    });
  }

  void _onNetLoaded() {
    _netLoaded = true;
    if (mounted && widget.active && _phase == _Phase.loading) {
      _wait?.cancel();
      _show(_Phase.network);
    }
  }

  void _onNetFailed() {
    _netFailed = true;
    if (mounted && widget.active && _phase == _Phase.loading) {
      _wait?.cancel();
      _fallback();
    }
  }

  void _fallback() {
    if (widget.ownBuilder != null) return _show(_Phase.own);
    setState(() => _phase = _Phase.skipped);
    _advance();   // aucune pub à montrer : la page se passe toute seule
  }

  void _show(_Phase p) {
    setState(() => _phase = p);
    _startCountdown(p == _Phase.network ? widget.networkSeconds : widget.ownSeconds);
  }

  void _startCountdown(int seconds, {bool restart = true}) {
    if (restart || _left <= 0) {
      _left = seconds;
      widget.onShown?.call(seconds);
    }
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || !widget.active) return t.cancel();
      setState(() => _left--);
      if (_left <= 0) {
        t.cancel();
        _advance();
      }
    });
  }

  void _advance() {
    if (_advanced) return;
    _advanced = true;
    _callNext(0);
  }

  /// Passe à la suite. Avec [FullScreenAdPage.retryNext], si la page est toujours regardée 0,7 s plus tard (défilement en cours, page suivante pas encore prête), on redemande :
  /// jamais d'attente sans fin devant un écran de chargement (6 essais au plus).
  void _callNext(int attempt, {bool direct = false}) {
    void call() {
      if (!mounted) return;
      widget.onNext();
      if (widget.retryNext && attempt < 6) {
        _retryNext?.cancel();
        // directement depuis le minuteur (pas d'attente d'une image : une page sans animation n'en demande plus)
        _retryNext = Timer(const Duration(milliseconds: 700), () {
          if (mounted && widget.active) _callNext(attempt + 1, direct: true);
        });
      }
    }

    direct ? call() : WidgetsBinding.instance.addPostFrameCallback((_) => call());
  }

  @override
  Widget build(BuildContext context) {
    final net = (widget.networkBuilder ?? (loaded, failed) => AdBanner(mrec: true, onLoaded: loaded, onFailed: failed))(_onNetLoaded, _onNetFailed);
    final showNet = _phase == _Phase.network;
    return Container(
      color: Colors.black,
      child: Stack(fit: StackFit.expand, children: [
        // la pub du réseau se charge dès que la page est construite, hors de la vue ; elle n'apparaît qu'une fois prête
        if (_phase == _Phase.loading || showNet) Center(child: Offstage(offstage: !showNet, child: net)),
        if (_phase == _Phase.own && widget.ownBuilder != null) Positioned.fill(child: widget.ownBuilder!(_advance)),
        // le cercle ne tourne que pendant le chargement (3 s au plus) : une page « sans pub » ne fait plus semblant de charger
        if (_phase == _Phase.loading)
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white54)),
              const SizedBox(height: 12),
              Text(context.tr('Publicité'), style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: .8)),
            ]),
          ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 56,
          left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(99), border: Border.all(color: Colors.white24)),
            child: Text(context.tr('Annonce'), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
          ),
        ),
        if (widget.showCountdown && (_phase == _Phase.network || _phase == _Phase.own) && _left > 0)
          Positioned(
            top: MediaQuery.of(context).padding.top + 56,
            right: 12,
            child: Container(
              key: const ValueKey('ad_countdown'),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(99), border: Border.all(color: Colors.white24)),
              child: Text('${context.tr('Suivant dans')} $_left s', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
            ),
          ),
      ]),
    );
  }
}
