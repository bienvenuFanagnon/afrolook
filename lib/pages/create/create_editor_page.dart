import '../../widgets/gold_badge.dart';
import '../../widgets/widgets_sheet.dart';
import '../../widgets/draft_widgets_layer.dart';
import '../../models/post_widget.dart';
import '../../services/create_draft.dart';
import '../../widgets/reply_banner.dart';
import 'package:provider/provider.dart';
import '../../providers/authProvider.dart';
import '../../ads/gold_gate.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../l10n/tr.dart';
import '../../models/model_data.dart';
import '../../services/api/studio_subtitles_api.dart';
import '../../services/api/studio_trim_api.dart';
import '../../services/api/studio_time_api.dart';
import '../../services/montage_signature.dart';
import '../../services/post_source_link.dart';
import '../../theme/app_colors.dart';
import '../../widgets/api_error_dialogs.dart';
import '../../widgets/original_badge.dart';
import '../studio/montage/montage_catalog.dart';
import '../studio/montage/montage_editor_page.dart';
import '../studio/montage/montage_gallery_page.dart';
import '../studio/montage/montage_music.dart';
import '../studio/montage/montage_pin.dart';
import '../studio/montage/montage_preview_page.dart';
import 'chronique_flow.dart' show ChroniqueFlow;
import '../studio/studio_models.dart';
import 'create_flow.dart';
import 'create_result.dart';
import 'subtitles_sheet.dart';
import 'voice_effect_page.dart';
import 'trim_sheet.dart';

/// Écran de retouche du parcours « Créer un post » (écran 5 de la proposition) : le média en plein écran, les outils en bas (Modèles, Musique, Texte, Effets, Couper),
/// la barre de lecture, puis « Refaire » et « Suivant ». Les commandes posées sur le média restent blanches sur un voile sombre : elles sont lisibles quelle que soit
/// l'image, en thème clair comme en thème sombre.
///
/// Les outils réutilisent le Studio existant : « Modèles » ouvre les modèles prêts à poster sur ce média, « Musique », « Texte » et « Effets » ouvrent l'éditeur sans
/// habillage (musique gratuite ou d'artiste, texte libre, looks de couleur sobres), « Couper » garde un passage de la vidéo (découpe faite par le serveur).
class CreateEditorPage extends StatefulWidget {
  const CreateEditorPage({super.key, required this.path, required this.isVideo, required this.source, this.canal, this.defiPostId, this.sound, this.pin, this.draft});

  final String path;
  final bool isVideo;

  /// Origine du média : filmé dans l'application ou choisi dans la galerie.
  final String source;
  final Canal? canal;
  final String? defiPostId;

  /// « Créer avec ce son » : le Studio s'ouvre tout de suite avec ce son sur le média (la voix de la vidéo est coupée, on peut la garder dans le Studio).
  final MontageMusic? sound;

  /// Vidéo d'un autre à épingler : le Studio s'ouvre tout de suite avec elle posée dans le coin.
  final MontagePinSource? pin;

  /// Brouillon repris : l'effet de voix et les widgets sont remis comme ils étaient.
  final CreateDraft? draft;

  @override
  State<CreateEditorPage> createState() => _CreateEditorPageState();
}

class _CreateEditorPageState extends State<CreateEditorPage> {
  late String _path = widget.path;
  VideoPlayerController? _video;
  bool _busy = false;
  bool _pausedByUser = false;   // la personne a mis la vidéo en pause : on ne la relance pas toute seule

  /// Outil utilisé : le média est désormais retouché dans le Studio d'Afrolook (mention « Fait sur Afrolook »).
  bool _touched = false;
  double? _imgAspect; // format réel de la photo (largeur / hauteur)
  String? _voiceEffect; // effet de voix choisi pour la vidéo (mention « Voix modifiée »)
  bool _subtitlesOk = false; // le serveur sait transcrire (service réglé)

  @override
  void initState() {
    super.initState();
    MontageSignature.setCanal(widget.canal);   // post de canal : la signature du montage est « #titre », jamais le pseudo
    final dr = widget.draft;
    if (dr != null) {
      _voiceEffect = dr.voiceEffect;
      _touched = dr.touched;
      PostWidgetsLink.drafts.value = [for (final w in dr.widgets) w.copy()];
    }
    if (widget.isVideo) {
      _initVideo();
      _checkSubtitles();
    } else {
      _loadImageAspect();
    }
    if (widget.sound != null || widget.pin != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openStudio(MontageEditorPage(template: kPlainTemplate, presetMusic: widget.sound, presetKeepAudio: widget.sound == null, presetPin: widget.pin, presetVideoPath: _presetVideo, presetPhotoPath: _presetPhoto));
      });
    }
  }

  @override
  void dispose() {
    MontageSignature.clear();
    _video?.dispose();
    super.dispose();
  }

  Future<void> _loadImageAspect() async {
    try {
      final img = await decodeImageFromList(await File(_path).readAsBytes());
      if (mounted && img.height > 0) setState(() => _imgAspect = img.width / img.height);
    } catch (_) {}
  }

  /// Format réel du média affiché (vidéo ou photo) : il est montré EN ENTIER, tel qu'il sera partout (publication, chronique…).
  double? get _mediaAspect {
    final v = _video;
    if (widget.isVideo) return (v != null && v.value.isInitialized && v.value.size.height > 0) ? v.value.aspectRatio : null;
    return _imgAspect;
  }

  Future<void> _checkSubtitles() async {
    final ok = await StudioSubtitlesApi.available();
    if (mounted && ok != _subtitlesOk) setState(() => _subtitlesOk = ok);
  }

  Future<void> _initVideo() async {
    final old = _video;
    final v = VideoPlayerController.file(File(_path), videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));   // sans « focus audio » : un son joué à côté ne met pas la vidéo en pause
    _video = v;
    old?.dispose();
    try {
      await v.initialize();
      await v.setLooping(true);
      await v.play();
      // certains téléphones n'animent l'image qu'après un second « lecture » : on vérifie et on relance
      Future<void>.delayed(const Duration(milliseconds: 900), () async {
        if (mounted && identical(_video, v) && v.value.isInitialized && !v.value.isPlaying && !_pausedByUser) {
          await v.seekTo(Duration.zero);
          await v.play();
          if (mounted) setState(() {});
        }
      });
    } catch (_) {
      if (mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(context.tr('La vidéo ne peut pas être lue ici (format non pris en charge). Elle sera quand même utilisée telle quelle.'))));
    }
    if (mounted) setState(() {});
  }

  Future<void> _finish(String r) async {
    if (r == kCreateDone) await CreateDraft.clear();   // publié : plus de brouillon
    if (r == kCreateDone && mounted) Navigator.of(context).pop(kCreateDone);
  }

  Future<void> _next() async {
    _video?.pause();
    final media = File(_path);   // aucune signature dans le média publié : elle n'est posée qu'au téléchargement (comme sur TikTok)
    if (!mounted) return;
    // Aperçu final AVANT « Nouveau post » : on regarde (et on entend) exactement ce qui sera publié ; « Modifier » revient ici, « Poursuivre » continue.
    // (Dans un parcours de chronique, l'aperçu de la chronique suit déjà.)
    if (ChroniqueFlow.active == null) {
      final go = await Navigator.of(context).push<bool>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => MontagePreviewPage(file: media, video: widget.isVideo)));
      if (go != true || !mounted) {
        _video?.play();
        return;
      }
    }
    final result = StudioResult(type: widget.isVideo ? StudioContentType.video : StudioContentType.image, mediaFile: media);
    // un passage coupé dans l'éditeur compte comme retouché dans notre Studio
    final source = (_touched && widget.source != PostSourceLink.captured) ? PostSourceLink.edited : widget.source;
    if (widget.isVideo && _voiceEffect != null) PostVoiceLink.set(_voiceEffect);
    final r = await openCreateForm(context, studio: result, canal: widget.canal, defiPostId: widget.defiPostId, source: source);
    PostVoiceLink.clear();
    if (r == kCreateBack) _video?.play();
    await _finish(r);
  }

  /// [asSheet] : la page s'ouvre en feuille par-dessus l'éditeur (la vidéo reste visible derrière), comme dans la proposition, au lieu de prendre tout l'écran.
  Future<void> _openStudio(Widget page, {bool asSheet = false}) async {
    _video?.pause();
    final StudioResult? result = asSheet
        ? await showModalBottomSheet<StudioResult>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            backgroundColor: Colors.transparent,
            builder: (ctx) => ClipRRect(
              key: const ValueKey('models_sheet'),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              child: SizedBox(height: MediaQuery.sizeOf(ctx).height * 0.88, child: page),
            ),
          )
        : await Navigator.of(context).push<StudioResult>(MaterialPageRoute(builder: (_) => page));
    if (!mounted) return;
    if (result == null) {
      _video?.play();
      return;
    }
    _touched = true;
    // retouché dans le Studio : marqué « Fait sur Afrolook » (filmé : comme filmé ; galerie : « édité », qui compte dans la limite du jour)
    final edited = widget.source == PostSourceLink.captured ? PostSourceLink.captured : PostSourceLink.edited;
    final r = await openCreateForm(context, studio: result, canal: widget.canal, defiPostId: widget.defiPostId, source: edited);
    if (r == kCreateBack) _video?.play();
    await _finish(r);
  }

  String? get _presetVideo => widget.isVideo ? _path : null;
  String? get _presetPhoto => widget.isVideo ? null : _path;

  // ── Annuler / brouillon ──────────────────────────────────────────────────

  /// Chaque changement (voix, sous-titres, découpe, temps, widgets) garde l'état d'avant : « Annuler » revient en arrière, autant de fois que nécessaire.
  final List<_EditSnapshot> _history = [];
  int? _timeIdx;   // position dans l'historique avant le premier effet de temps : sert à « Vitesse normale »

  _EditSnapshot _snap() => _EditSnapshot(_path, _voiceEffect, _touched, [for (final w in PostWidgetsLink.drafts.value) w.copy()]);

  void _remember() {
    _history.add(_snap());
    if (_history.length > 20) {
      _history.removeAt(0);
      if (_timeIdx != null) _timeIdx = _timeIdx! > 0 ? _timeIdx! - 1 : null;
    }
  }

  Future<void> _restore(_EditSnapshot s) async {
    final mediaChanged = s.path != _path;
    _path = s.path;
    _voiceEffect = s.voice;
    _touched = s.touched;
    PostWidgetsLink.drafts.value = s.widgets;
    if (mediaChanged && widget.isVideo) {
      await _initVideo();
    } else if (mounted) {
      setState(() {});
    }
  }

  Future<void> _undo() async {
    if (_history.isEmpty || _busy) return;
    final s = _history.removeLast();
    if (_timeIdx != null && _history.length < _timeIdx!) _timeIdx = null;
    await _restore(s);
  }

  /// Quitter l'éditeur (bouton retour de l'application ou du téléphone) : on demande avant de perdre le travail.
  Future<void> _leave() async {
    if (_busy) return;
    final c = AppColors.of(context);
    _video?.pause();
    final act = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text(context.tr('Quitter la retouche ?'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
        content: Text(context.tr('Ce que tu as fait sur ce média sera perdu, sauf si tu l\'enregistres en brouillon pour le reprendre plus tard.'), style: TextStyle(color: c.textSecondary)),
        actionsOverflowDirection: VerticalDirection.down,
        actionsOverflowButtonSpacing: 4,
        actions: [
          TextButton(key: const ValueKey('leave_stay'), onPressed: () => Navigator.pop(ctx, 'stay'), child: Text(context.tr('Continuer la retouche'))),
          TextButton(key: const ValueKey('leave_save'), onPressed: () => Navigator.pop(ctx, 'save'), child: Text(context.tr('Enregistrer en brouillon'))),
          TextButton(key: const ValueKey('leave_discard'), onPressed: () => Navigator.pop(ctx, 'discard'), child: Text(context.tr('Supprimer et quitter'), style: TextStyle(color: c.danger))),
        ],
      ),
    );
    if (!mounted) return;
    if (act == 'save') {
      await CreateDraft.save(path: _path, isVideo: widget.isVideo, source: widget.source, voiceEffect: _voiceEffect, widgets: PostWidgetsLink.drafts.value, touched: _touched);
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(context.tr('Brouillon enregistré. Tu le retrouveras dans « Créer ».'))));
      Navigator.of(context).pop(kCreateBack);
    } else if (act == 'discard') {
      await CreateDraft.clear();
      if (mounted) Navigator.of(context).pop(kCreateBack);
    } else if (!_pausedByUser) {
      _video?.play();
    }
  }

  // ── Musique ──────────────────────────────────────────────────────────────

  /// Feuille « Musique » par-dessus la vidéo : on choisit une piste (gratuite ou d'artiste) en l'écoutant ; pour une vidéo, on décide aussi de garder ou non son propre son.
  /// Une fois la piste choisie, l'éditeur de montage s'ouvre directement avec elle.
  Future<void> _music() async {
    _video?.pause();
    final pick = await showMontageMusicPicker(context, onArtistCta: () => openArtistSpace(context), offerKeepAudio: widget.isVideo);
    if (!mounted) return;
    if (pick == null || pick.music == null) {
      _video?.play();
      return;
    }
    await _openStudio(MontageEditorPage(template: kPlainTemplate, presetMusic: pick.music, presetKeepAudio: pick.keepVideoAudio, presetVideoPath: _presetVideo, presetPhotoPath: _presetPhoto));
  }

  // ── Voix ─────────────────────────────────────────────────────────────────

  /// Change la voix de la vidéo : on essaie les effets en écoutant le vrai rendu du serveur ; l'image reste intacte.
  Future<void> _voice() async {
    final v = _video;
    if (!widget.isVideo || v == null || !v.value.isInitialized || _busy) return;
    v.pause();
    final choice = await Navigator.of(context).push<VoiceChoice>(MaterialPageRoute(builder: (_) => VoiceEffectPage(original: File(_path), isVideo: true)));
    if (!mounted) return;
    if (choice == null || choice.effect == null) {
      v.play();
      return;
    }
    _remember();
    _path = choice.file.path;
    _voiceEffect = choice.effect;
    _touched = true;
    await _initVideo();
  }

  // ── Sous-titres ──────────────────────────────────────────────────────────

  Future<void> _subtitles() async {
    final v = _video;
    if (!widget.isVideo || v == null || !v.value.isInitialized || _busy) return;
    v.pause();
    setState(() => _busy = true);
    try {
      final found = await StudioSubtitlesApi.transcribe(File(_path));
      if (!mounted) return;
      setState(() => _busy = false);
      if (found.isEmpty) {
        v.play();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Aucune parole reconnue dans cette vidéo.'))));
        return;
      }
      final checked = await showSubtitlesSheet(context, found);
      if (!mounted) return;
      if (checked == null || checked.isEmpty) {
        v.play();
        return;
      }
      setState(() => _busy = true);
      final out = await StudioSubtitlesApi.burn(File(_path), checked);
      if (!mounted) return;
      _remember();
      _path = out.path;
      _touched = true;
      _busy = false;
      await _initVideo();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      v.play();
      handleApiError(context, e, onRetry: _subtitles, fallback: context.tr('Les sous-titres n\'ont pas pu être ajoutés. Réessaie.'));
    }
  }

  // ── Couper ───────────────────────────────────────────────────────────────

  Future<void> _trim() async {
    final v = _video;
    if (!widget.isVideo || v == null || !v.value.isInitialized || _busy) return;
    final total = v.value.duration.inMilliseconds;
    if (total < 2000) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Cette vidéo est trop courte pour être coupée.'))));
      return;
    }
    v.pause();
    final picked = await showTrimSheet(context, totalMs: total, title: context.tr('Couper la vidéo'));
    if (!mounted) return;
    if (picked == null || (picked.start <= 0 && picked.end >= total - 50)) {
      v.play();
      return;
    }
    setState(() => _busy = true);
    try {
      final out = await StudioTrimApi.trim(File(_path), isVideo: true, startMs: picked.start.round(), endMs: picked.end.round());
      if (!mounted) return;
      _remember();
      _path = out.path;
      _touched = true;
      _busy = false;
      await _initVideo();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      v.play();
      handleApiError(context, e, onRetry: _trim, fallback: context.tr('La découpe a échoué. Réessaie.'));
    }
  }

  // ── Temps : accéléré, ralenti, rembobinage, boomerang, rampe de vitesse ───

  Future<void> _time() async {
    final v = _video;
    if (!widget.isVideo || v == null || !v.value.isInitialized || _busy) return;
    if (!await GoldGate.feature(context, context.read<UserAuthProvider>().loginUserData.id ?? '', 'time_effects') || !mounted) return;
    final seconds = v.value.duration.inMilliseconds / 1000;
    v.pause();
    final key = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1B1B1B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.tr('Jouer avec le temps'), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            if (_timeIdx != null)
              ListTile(
                key: const ValueKey('time_normal'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.restart_alt_rounded, size: 28, color: Colors.white),
                title: Text(context.tr('Revenir à la vitesse normale'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                subtitle: Text(context.tr('Retire l\'effet de temps appliqué.'), style: const TextStyle(color: Colors.white60, fontSize: 12.5)),
                onTap: () => Navigator.pop(c, 'normal'),
              ),
            for (final e in StudioTimeApi.effects)
              ListTile(
                key: ValueKey('time_${e.$1}'),
                contentPadding: EdgeInsets.zero,
                enabled: seconds <= StudioTimeApi.maxSeconds(e.$1),
                leading: Icon(e.$3, size: 28, color: const Color(0xFFFFC400)),
                title: Text(context.tr(e.$2), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                subtitle: Text(
                  seconds <= StudioTimeApi.maxSeconds(e.$1) ? '${context.tr('Résultat')} : ${(seconds * e.$4).round()} s' : context.tr('Vidéo trop longue pour cet effet : coupe-la d\'abord.'),
                  style: const TextStyle(color: Colors.white60, fontSize: 12.5),
                ),
                onTap: () => Navigator.pop(c, e.$1),
              ),
          ]),
        ),
      ),
    );
    if (!mounted) return;
    if (key == null) {
      v.play();
      return;
    }
    if (key == 'normal' && _timeIdx != null && _timeIdx! < _history.length) {
      final base = _history[_timeIdx!];
      _history.removeRange(_timeIdx!, _history.length);
      _timeIdx = null;
      await _restore(base);
      return;
    }
    setState(() => _busy = true);
    try {
      final out = await StudioTimeApi.apply(File(_path), key);
      if (!mounted) return;
      _timeIdx ??= _history.length;
      _remember();
      _path = out.path;
      _touched = true;
      _busy = false;
      await _initVideo();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      v.play();
      handleApiError(context, e, onRetry: _time, fallback: context.tr('L\'effet n\'a pas pu être appliqué. Réessaie.'));
    }
  }

  // ── Écran ────────────────────────────────────────────────────────────────

  // ── Widgets ───────────────────────────────────────────────────────

  Future<void> _addWidget() async {
    if (PostWidgetsLink.isFull) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(context.tr('3 widgets au plus par publication.'))));
      return;
    }
    _video?.pause();
    final w = await addWidgetFlow(context);
    if (w != null) {
      _remember();
      PostWidgetsLink.add(w);
    }
    if (mounted && !_pausedByUser) _video?.play();
  }

  /// Calque des widgets : le même composant que dans le Studio (déplacer, redimensionner, durée, modifier, supprimer).
  Widget _widgetsLayer() => DraftWidgetsLayer(
        mediaAspect: _mediaAspect,
        videoSeconds: () {
          final v = _video;
          return widget.isVideo && v != null && v.value.isInitialized ? v.value.duration.inMilliseconds / 1000 : null;
        },
        onBeforeChange: _remember,
      );

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final v = _video;
    final ready = widget.isVideo && v != null && v.value.isInitialized;
    final showBadge = widget.source == PostSourceLink.captured || _touched;
    const shadow = [Shadow(color: Color(0x99000000), blurRadius: 4)];
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
      backgroundColor: Colors.black,
      body: Stack(fit: StackFit.expand, children: [
        // média plein écran
        if (widget.isVideo)
          (ready
              ? GestureDetector(
                  onTap: () => setState(() {
                    _pausedByUser = v.value.isPlaying;
                    v.value.isPlaying ? v.pause() : v.play();
                  }),
                  child: Center(child: AspectRatio(aspectRatio: v.value.aspectRatio, child: VideoPlayer(v))),   // format réel, jamais recadré
                )
              : const Center(child: CircularProgressIndicator(color: Colors.white54)))
        else
          Center(child: Image.file(File(_path), fit: BoxFit.contain)),
        // voiles haut et bas : les commandes restent lisibles sur n'importe quelle image
        const Positioned(top: 0, left: 0, right: 0, height: 130, child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x99000000), Color(0x00000000)]))))),
        const Positioned(bottom: 0, left: 0, right: 0, height: 300, child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00000000), Color(0xDD000000)]))))),
        // widgets posés (sondage, question, lien…) : déplaçables au doigt, un toucher ouvre le menu
        Positioned.fill(child: _widgetsLayer()),
        // réponse en vidéo : à quelle publication on répond (sous la rangée du haut, à gauche des outils)
        Positioned(top: MediaQuery.of(context).padding.top + 58, left: 12, right: 66, child: const Align(alignment: Alignment.centerLeft, child: ReplyBanner())),
        SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 12, 0),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _round(key: const ValueKey('editor_back'), icon: Icons.chevron_left_rounded, size: 40, onTap: () => Navigator.of(context).maybePop()),
                const SizedBox(width: 8),
                if (showBadge) const Padding(padding: EdgeInsets.only(top: 6), child: OriginalBadge()),
                if (_history.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _round(key: const ValueKey('editor_undo'), icon: Icons.undo_rounded, size: 40, onTap: _undo),
                ],
                const Spacer(),
                if (ready)
                  Column(children: [
                    _round(key: const ValueKey('tool_trim_top'), icon: Icons.content_cut_rounded, size: 40, onTap: _trim),
                    const SizedBox(height: 4),
                    Text(trimClock(v.value.duration.inMilliseconds), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700, shadows: shadow)),
                    const SizedBox(height: 10),
                    _round(key: const ValueKey('tool_voice'), icon: Icons.record_voice_over_rounded, size: 40, onTap: _voice),
                    const SizedBox(height: 4),
                    Text(context.tr('Voix'), style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700, shadows: shadow)),
                    const SizedBox(height: 10),
                    _round(key: const ValueKey('tool_time'), icon: Icons.speed_rounded, size: 40, onTap: _time, gold: 'time_effects'),
                    const SizedBox(height: 4),
                    Text(context.tr('Temps'), style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700, shadows: shadow)),
                    if (_subtitlesOk) ...[
                      const SizedBox(height: 10),
                      _round(key: const ValueKey('tool_subtitles'), icon: Icons.closed_caption_rounded, size: 40, onTap: _subtitles),
                      const SizedBox(height: 4),
                      Text(context.tr('Sous-titres'), style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700, shadows: shadow)),
                    ],
                  ]),
              ]),
            ),
            if (!widget.isVideo)
              Container(
                key: const ValueKey('photo_banner'),
                margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: const Color(0xCC15171A), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0x55FFC400))),
                child: Row(children: [
                  const Icon(Icons.movie_creation_rounded, color: Color(0xFFFFC400), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(context.tr('Avec musique : vidéo de 15 s'), style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800)),
                      Text(context.tr('Sans musique, l\'image reste fixe'), style: const TextStyle(color: Color(0xFFC9CDD2), fontSize: 12)),
                    ]),
                  ),
                ]),
              ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _tool('tool_models', Icons.dashboard_customize_rounded, context.tr('Modèles'), () => _openStudio(MontageGalleryPage(presetVideoPath: _presetVideo, presetPhotoPath: _presetPhoto), asSheet: true)),
                _tool('tool_music', Icons.music_note_rounded, context.tr('Musique'), _music),
                _tool('tool_text', Icons.title_rounded, context.tr('Texte'), () => _openStudio(MontageEditorPage(template: kPlainTemplate, focus: 'text', presetVideoPath: _presetVideo, presetPhotoPath: _presetPhoto))),
                _tool('tool_stickers', Icons.emoji_emotions_rounded, context.tr('Autocollants'), () => _openStudio(MontageEditorPage(template: kPlainTemplate, focus: 'stickers', presetVideoPath: _presetVideo, presetPhotoPath: _presetPhoto))),
                _tool('tool_widgets', Icons.widgets_rounded, context.tr('Widgets'), _addWidget),
                _tool('tool_looks', Icons.star_rounded, context.tr('Effets'), () => _openStudio(MontageEditorPage(template: kPlainTemplate, focus: 'looks', presetVideoPath: _presetVideo, presetPhotoPath: _presetPhoto))),
                if (widget.isVideo) _tool('tool_two', Icons.splitscreen_rounded, context.tr('2e média'), () => _openStudio(MontageEditorPage(template: kPlainTemplate, focus: 'second', presetVideoPath: _presetVideo, presetPhotoPath: _presetPhoto))),
                if (widget.isVideo) _tool('tool_trim', Icons.content_cut_rounded, context.tr('Couper'), _trim),
              ]),
            ),
            if (ready)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: VideoProgressIndicator(v, allowScrubbing: true, colors: const VideoProgressColors(playedColor: Color(0xFFFFC400), bufferedColor: Color(0x55FFFFFF), backgroundColor: Color(0x33FFFFFF)), padding: const EdgeInsets.symmetric(vertical: 8)),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: Row(children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: FilledButton(
                      key: const ValueKey('editor_redo'),
                      onPressed: _busy ? null : () => Navigator.of(context).pop(kCreateRedo),
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF272B30), foregroundColor: const Color(0xFFF3F1EA), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      child: Text(context.tr('Refaire'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 50,
                    child: FilledButton(
                      key: const ValueKey('editor_next'),
                      onPressed: _busy ? null : _next,
                      style: FilledButton.styleFrom(backgroundColor: c.accent, foregroundColor: c.onAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      child: Text(context.tr('Suivant'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    ),
                  ),
                ),
              ]),
            ),
          ]),
        ),
        if (_busy)
          Positioned.fill(
            child: ColoredBox(
              color: const Color(0xAA000000),
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const CircularProgressIndicator(color: Color(0xFFFFC400)),
                  const SizedBox(height: 14),
                  Text(context.tr('Découpe en cours…'), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ),
      ]),
    ),
    );
  }

  /// Bouton rond posé sur le média : fond sombre translucide, icône blanche.
  Widget _round({required Key key, required IconData icon, required double size, required VoidCallback onTap, String? gold}) => GestureDetector(
        key: key,
        onTap: onTap,
        child: Stack(clipBehavior: Clip.none, children: [
          Container(width: size, height: size, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x66000000)), child: Icon(icon, color: Colors.white, size: size * .6)),
          // option réservée à Gold et encore fermée : pastille GOLD ; un toucher propose Gold ou des pubs
          if (GoldBadge.locked(gold)) const Positioned(top: -4, right: -8, child: GoldBadge(compact: true)),
        ]),
      );

  Widget _tool(String key, IconData icon, String label, VoidCallback onTap) => Expanded(
      child: GestureDetector(
        key: ValueKey(key),
        behavior: HitTestBehavior.opaque,
        onTap: _busy
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap();
              },
        child: SizedBox(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 44, height: 44, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x66000000)), child: Icon(icon, color: Colors.white, size: 22)),
            const SizedBox(height: 5),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700, shadows: [Shadow(color: Color(0x99000000), blurRadius: 4)])),
          ]),
        ),
      ),
    );
}

/// État de la retouche à un instant donné (pour « Annuler »).
class _EditSnapshot {
  _EditSnapshot(this.path, this.voice, this.touched, this.widgets);
  final String path;
  final String? voice;
  final bool touched;
  final List<PostWidget> widgets;
}
