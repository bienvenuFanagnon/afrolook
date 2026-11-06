import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../l10n/tr.dart';
import '../../models/model_data.dart';
import '../../services/api/studio_subtitles_api.dart';
import '../../services/api/studio_trim_api.dart';
import '../../services/post_source_link.dart';
import '../../theme/app_colors.dart';
import '../../widgets/api_error_dialogs.dart';
import '../../widgets/original_badge.dart';
import '../studio/montage/montage_catalog.dart';
import '../studio/montage/montage_editor_page.dart';
import '../studio/montage/montage_gallery_page.dart';
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
  const CreateEditorPage({super.key, required this.path, required this.isVideo, required this.source, this.canal, this.defiPostId});

  final String path;
  final bool isVideo;

  /// Origine du média : filmé dans l'application ou choisi dans la galerie.
  final String source;
  final Canal? canal;
  final String? defiPostId;

  @override
  State<CreateEditorPage> createState() => _CreateEditorPageState();
}

class _CreateEditorPageState extends State<CreateEditorPage> {
  late String _path = widget.path;
  VideoPlayerController? _video;
  bool _busy = false;

  /// Outil utilisé : le média est désormais retouché dans le Studio d'Afrolook (mention « Fait sur Afrolook »).
  bool _touched = false;
  String? _voiceEffect; // effet de voix choisi pour la vidéo (mention « Voix modifiée »)
  bool _subtitlesOk = false; // le serveur sait transcrire (service réglé)

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      _initVideo();
      _checkSubtitles();
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  Future<void> _checkSubtitles() async {
    final ok = await StudioSubtitlesApi.available();
    if (mounted && ok != _subtitlesOk) setState(() => _subtitlesOk = ok);
  }

  Future<void> _initVideo() async {
    final old = _video;
    final v = VideoPlayerController.file(File(_path));
    _video = v;
    old?.dispose();
    try {
      await v.initialize();
      await v.setLooping(true);
      await v.play();
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _finish(String r) async {
    if (r == kCreateDone && mounted) Navigator.of(context).pop(kCreateDone);
  }

  Future<void> _next() async {
    _video?.pause();
    final result = StudioResult(type: widget.isVideo ? StudioContentType.video : StudioContentType.image, mediaFile: File(_path));
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

  // ── Écran ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final v = _video;
    final ready = widget.isVideo && v != null && v.value.isInitialized;
    final showBadge = widget.source == PostSourceLink.captured || _touched;
    const shadow = [Shadow(color: Color(0x99000000), blurRadius: 4)];
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(fit: StackFit.expand, children: [
        // média plein écran
        if (widget.isVideo)
          (ready
              ? GestureDetector(
                  onTap: () => setState(() => v.value.isPlaying ? v.pause() : v.play()),
                  child: FittedBox(fit: BoxFit.cover, clipBehavior: Clip.hardEdge, child: SizedBox(width: v.value.size.width, height: v.value.size.height, child: VideoPlayer(v))),
                )
              : const Center(child: CircularProgressIndicator(color: Colors.white54)))
        else
          Image.file(File(_path), fit: BoxFit.cover),
        // voiles haut et bas : les commandes restent lisibles sur n'importe quelle image
        const Positioned(top: 0, left: 0, right: 0, height: 130, child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x99000000), Color(0x00000000)]))))),
        const Positioned(bottom: 0, left: 0, right: 0, height: 300, child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00000000), Color(0xDD000000)]))))),
        SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 12, 0),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _round(key: const ValueKey('editor_back'), icon: Icons.chevron_left_rounded, size: 40, onTap: () => Navigator.of(context).maybePop()),
                const SizedBox(width: 8),
                if (showBadge) const Padding(padding: EdgeInsets.only(top: 6), child: OriginalBadge()),
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
                _tool('tool_music', Icons.music_note_rounded, context.tr('Musique'), () => _openStudio(MontageEditorPage(template: kPlainTemplate, focus: 'music', presetVideoPath: _presetVideo, presetPhotoPath: _presetPhoto))),
                _tool('tool_text', Icons.title_rounded, context.tr('Texte'), () => _openStudio(MontageEditorPage(template: kPlainTemplate, focus: 'text', presetVideoPath: _presetVideo, presetPhotoPath: _presetPhoto))),
                _tool('tool_stickers', Icons.emoji_emotions_rounded, context.tr('Autocollants'), () => _openStudio(MontageEditorPage(template: kPlainTemplate, focus: 'stickers', presetVideoPath: _presetVideo, presetPhotoPath: _presetPhoto))),
                _tool('tool_looks', Icons.star_rounded, context.tr('Effets'), () => _openStudio(MontageEditorPage(template: kPlainTemplate, focus: 'looks', presetVideoPath: _presetVideo, presetPhotoPath: _presetPhoto))),
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
    );
  }

  /// Bouton rond posé sur le média : fond sombre translucide, icône blanche.
  Widget _round({required Key key, required IconData icon, required double size, required VoidCallback onTap}) => GestureDetector(
        key: key,
        onTap: onTap,
        child: Container(width: size, height: size, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x66000000)), child: Icon(icon, color: Colors.white, size: size * .6)),
      );

  Widget _tool(String key, IconData icon, String label, VoidCallback onTap) => GestureDetector(
        key: ValueKey(key),
        behavior: HitTestBehavior.opaque,
        onTap: _busy
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap();
              },
        child: SizedBox(
          width: 54,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 44, height: 44, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x66000000)), child: Icon(icon, color: Colors.white, size: 22)),
            const SizedBox(height: 5),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700, shadows: [Shadow(color: Color(0x99000000), blurRadius: 4)])),
          ]),
        ),
      );
}
