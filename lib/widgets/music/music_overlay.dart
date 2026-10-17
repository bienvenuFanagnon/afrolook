// Lecteur flottant d'Afrolook : une capsule au-dessus du contenu de toutes les pages tant qu'un titre est en cours.
// Aléatoire · pause · suivant · fermer. Masquée devant une vidéo (la musique se met alors en pause, puis reprend).
// Glissable verticalement pour ne jamais cacher un champ de saisie.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../ads/music_ads.dart';
import '../../pages/music/music_page.dart';
import '../../pages/studio/artist_marketplace.dart';
import '../../pages/studio/artist_sound_common.dart';
import '../../providers/authProvider.dart';
import '../../services/music_queue.dart';
import '../../services/nav_cache_service.dart';
import '../../theme/app_colors.dart';
import 'preview_end_sheet.dart';
import 'vinyl.dart';

/// Pages qui masquent le lecteur flottant.
class MusicOverlay {
  MusicOverlay._();
  static final ValueNotifier<int> hidden = ValueNotifier<int>(0);

  static void _add(int d) {
    WidgetsBinding.instance.addPostFrameCallback((_) => hidden.value = (hidden.value + d).clamp(0, 99));
  }
}

/// Enveloppe une page : le lecteur flottant est masqué tant qu'elle est ouverte.
/// [pause] : la musique se met aussi en pause (vidéo, live, appel…) et reprend à la fermeture de la page.
class HideMusicOverlay extends StatefulWidget {
  const HideMusicOverlay({super.key, required this.child, this.pause = false});
  final Widget child;
  final bool pause;

  @override
  State<HideMusicOverlay> createState() => _HideMusicOverlayState();
}

class _HideMusicOverlayState extends State<HideMusicOverlay> {
  @override
  void initState() {
    super.initState();
    MusicOverlay._add(1);
    if (widget.pause) MusicQueue.suspend(this);
  }

  @override
  void dispose() {
    MusicOverlay._add(-1);
    if (widget.pause) MusicQueue.release(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Pour les pages à vidéo, live ou éditeur : à ajouter aux `with` de leur State. Le lecteur flottant est masqué et la musique
/// se met en pause tant que la page est ouverte ; elle reprend à la fermeture.
mixin MusicSuspendMixin<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    MusicOverlay._add(1);
    MusicQueue.suspend(this);
  }

  @override
  void dispose() {
    MusicOverlay._add(-1);
    MusicQueue.release(this);
    super.dispose();
  }
}

/// Placé autour du Navigator (MaterialApp.builder) : affiche la capsule et la feuille de fin d'extrait.
class MusicOverlayHost extends StatefulWidget {
  const MusicOverlayHost({super.key, required this.child});
  final Widget child;

  @override
  State<MusicOverlayHost> createState() => _MusicOverlayHostState();
}

class _MusicOverlayHostState extends State<MusicOverlayHost> with WidgetsBindingObserver {
  StreamSubscription<MusicTrack>? _end;
  MusicTrack? _pendingEnd;
  bool _resumed = true;
  bool _sheetOpen = false;
  double _lift = 0; // décalage vertical choisi par la personne (glisser la capsule)

  BuildContext? get _navCtx => NavigationCacheService().navigatorKey.currentContext;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    MusicQueue.start();
    MusicQueue.interstitialHook = () async {
      final ctx = _navCtx;
      if (ctx == null) return;
      await MusicAds.beforeTrack(Provider.of<UserAuthProvider>(ctx, listen: false).loginUserData);
    };
    _end = MusicQueue.ends.listen(_onEnd);
    MusicQueue.error.addListener(_onError);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _end?.cancel();
    MusicQueue.error.removeListener(_onError);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    if (_resumed && _pendingEnd != null) {
      final t = _pendingEnd!;
      _pendingEnd = null;
      _openSheet(t);
    }
  }

  void _onEnd(MusicTrack t) {
    if (!_resumed) {
      _pendingEnd = t; // l'extrait s'est terminé en arrière-plan : on propose le titre au retour
      return;
    }
    _openSheet(t);
  }

  Future<void> _openSheet(MusicTrack t) async {
    final ctx = _navCtx;
    if (ctx == null || _sheetOpen || !ctx.mounted) return;
    _sheetOpen = true;
    try {
      await showPreviewEndSheet(ctx, t);
    } finally {
      _sheetOpen = false;
    }
  }

  void _onError() {
    final m = MusicQueue.error.value;
    if (m == null) return;
    MusicQueue.error.value = null;
    final ctx = _navCtx;
    if (ctx != null && ctx.mounted) ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(SnackBar(content: Text(m)));
  }

  void _openTrack(MusicTrack t) {
    final nav = NavigationCacheService().navigatorKey.currentState;
    if (nav == null) return;
    if (t.sound != null) {
      nav.push(MaterialPageRoute(builder: (_) => ArtistSoundDetailPage(sound: t.sound!)));
    } else if (t.isArtist) {
      final ctx = _navCtx;
      if (ctx != null) openArtistSoundById(ctx, t.id);
    } else {
      nav.push(MaterialPageRoute(builder: (_) => const MusicPage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final keyboard = mq.viewInsets.bottom > 0;
    return Stack(children: [
      widget.child,
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: ValueListenableBuilder<int>(
          valueListenable: MusicOverlay.hidden,
          builder: (_, hidden, __) => ValueListenableBuilder<MusicTrack?>(
            valueListenable: MusicQueue.current,
            builder: (_, t, __) => ValueListenableBuilder<NowPlaying?>(
              valueListenable: SoundPreview.now,
              builder: (_, now, __) {
                if (t == null || now == null || now.key != t.key || hidden > 0 || keyboard) return const SizedBox.shrink();
                return Padding(
                  padding: EdgeInsets.only(bottom: mq.padding.bottom + 10 + _lift),
                  child: GestureDetector(
                    behavior: HitTestBehavior.deferToChild,
                    onVerticalDragUpdate: (d) => setState(() => _lift = (_lift - d.delta.dy).clamp(0.0, mq.size.height - 260)),
                    child: _Capsule(track: t, onOpen: () => _openTrack(t), onEnded: () => _openSheet(t)),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ]);
  }
}

class _Capsule extends StatelessWidget {
  const _Capsule({required this.track, required this.onOpen, required this.onEnded});
  final MusicTrack track;
  final VoidCallback onOpen;
  final VoidCallback onEnded;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Material(
      type: MaterialType.transparency,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10),
        height: 56,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .22), blurRadius: 16, offset: const Offset(0, 5))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(children: [
            ValueListenableBuilder<bool>(
              valueListenable: MusicQueue.previewEnded,
              builder: (_, ended, __) => Row(children: [
                // Disque + titre : un toucher ouvre la fiche du titre
                Expanded(
                  child: InkWell(
                    onTap: onOpen,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(9, 0, 4, 0),
                      child: Row(children: [
                        TrackDisc(track: track, size: 38, glow: false),
                        const SizedBox(width: 9),
                        Expanded(child: _texts(c, ended)),
                      ]),
                    ),
                  ),
                ),
                if (ended)
                  _unlock(c)
                else ...[
                  ValueListenableBuilder<bool>(
                    valueListenable: MusicQueue.shuffle,
                    builder: (_, sh, __) => _ib(Icons.shuffle_rounded, MusicQueue.toggleShuffle, color: sh ? c.primary : c.textPrimary, bg: sh ? c.primary.withValues(alpha: .16) : null, tip: 'Aléatoire'),
                  ),
                  ValueListenableBuilder<String?>(
                    valueListenable: SoundPreview.playing,
                    builder: (_, p, __) => ValueListenableBuilder<bool>(
                      valueListenable: MusicQueue.loading,
                      builder: (_, ld, __) => GestureDetector(
                        onTap: MusicQueue.togglePlay,
                        child: Container(
                          width: 34,
                          height: 34,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
                          child: ld
                              ? Padding(padding: const EdgeInsets.all(9), child: CircularProgressIndicator(strokeWidth: 2, color: c.onPrimary))
                              : Icon(p == track.key ? Icons.pause_rounded : Icons.play_arrow_rounded, color: c.onPrimary, size: 22),
                        ),
                      ),
                    ),
                  ),
                  _ib(Icons.skip_next_rounded, () => MusicQueue.next(), tip: 'Suivant'),
                ],
                _ib(Icons.close_rounded, MusicQueue.close, color: c.textSecondary, tip: 'Fermer'),
                const SizedBox(width: 2),
              ]),
            ),
            // Barre de progression
            Positioned(left: 0, right: 0, bottom: 0, child: _bar(c)),
          ]),
        ),
      ),
    );
  }

  Widget _texts(AppColors c, bool ended) {
    return Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 12.5)),
      if (ended)
        Text('Extrait terminé', maxLines: 1, style: TextStyle(color: c.warning, fontWeight: FontWeight.w800, fontSize: 10.5))
      else
        ValueListenableBuilder<bool>(
          valueListenable: MusicQueue.previewMode,
          builder: (_, pv, __) => pv
              ? StreamBuilder<Duration>(
                  stream: SoundPreview.position,
                  builder: (_, p) {
                    final left = (30 - (p.data?.inSeconds ?? 0)).clamp(0, 30);
                    return Text('Extrait · $left s', maxLines: 1, style: TextStyle(color: c.primary, fontWeight: FontWeight.w800, fontSize: 10.5));
                  },
                )
              : Text(track.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textSecondary, fontWeight: FontWeight.w700, fontSize: 10.5)),
        ),
    ]);
  }

  Widget _unlock(AppColors c) {
    final price = track.saleCoins;
    return GestureDetector(
      onTap: onEnded,
      child: Container(
        height: 34,
        margin: const EdgeInsets.only(right: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(gradient: LinearGradient(colors: [c.primary, c.accent]), borderRadius: BorderRadius.circular(12)),
        alignment: Alignment.center,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.lock_open_rounded, size: 16, color: c.onAccent),
          const SizedBox(width: 5),
          Text(price > 0 ? 'Débloquer · $price 🪙' : 'Débloquer', style: TextStyle(color: c.onAccent, fontWeight: FontWeight.w900, fontSize: 11.5)),
        ]),
      ),
    );
  }

  Widget _ib(IconData icon, VoidCallback onTap, {Color? color, Color? bg, String? tip}) => Semantics(
        label: tip,
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon, size: 19, color: color ?? Colors.grey),
          ),
        ),
      );

  Widget _bar(AppColors c) {
    return StreamBuilder<Duration>(
      stream: SoundPreview.position,
      builder: (_, p) => StreamBuilder<Duration>(
        stream: SoundPreview.duration,
        builder: (_, d) {
          final total = d.data?.inMilliseconds ?? 0;
          final v = total > 0 ? ((p.data?.inMilliseconds ?? 0) / total).clamp(0.0, 1.0) : 0.0;
          return ValueListenableBuilder<bool>(
            valueListenable: MusicQueue.previewEnded,
            builder: (_, ended, __) => LinearProgressIndicator(value: ended ? 1 : v, minHeight: 3, backgroundColor: c.border, valueColor: AlwaysStoppedAnimation<Color>(ended ? c.warning : c.primary)),
          );
        },
      ),
    );
  }
}
