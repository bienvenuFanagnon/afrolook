import 'dart:io';
import 'dart:typed_data';

import 'package:afrolook_api_client/afrolook_api_client.dart' show ApiException;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../l10n/tr.dart';
import '../../../services/api/argent_upload.dart';
import '../../../services/api/studio_slideshow_api.dart';
import '../../../services/authentic_video_check.dart';
import '../../../services/post_source_link.dart';
import '../../../services/template_link.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/api_error_dialogs.dart';
import '../../create/create_editor_page.dart';
import '../../create/create_result.dart';
import 'credits_render.dart';
import 'credits_subjects.dart';
import 'montage_catalog.dart';
import 'montage_music.dart';
import 'story_render.dart';
import 'story_script.dart';

/// « Le film de mon année » (10/11/2026) : comme la fin d'un film, le texte MONTE lentement sur des photos qui changent, puis « FIN ».
/// La personne écrit son générique (une ligne par rôle : « Rôle · Nom »), choisit 1 à 5 photos et la durée ; l'aperçu joue exactement ce que la vidéo montrera.
class CreditsTemplatePage extends StatefulWidget {
  const CreditsTemplatePage({super.key, required this.template});
  final MontageTemplate template;

  @override
  State<CreditsTemplatePage> createState() => _CreditsTemplatePageState();
}

class _CreditsTemplatePageState extends State<CreditsTemplatePage> with SingleTickerProviderStateMixin {
  final List<XFile> _photos = [];
  final Map<String, Uint8List> _bytes = {};
  List<Uint8List> _samples = const [];   // photos d'exemple de l'application : seulement pour l'aperçu
  CreditsStyle _style = CreditsStyle.classique;
  late final TextEditingController _text = TextEditingController(text: creditsDefaultLinesFor(widget.template.id).join('\n'));
  late final AnimationController _anim = AnimationController(vsync: this);
  double _seconds = 24;
  Uint8List? _credits;   // le texte dessiné pour l'aperçu
  double _creditsH = 1;
  bool _busy = false;
  String _busyLabel = '';

  /// La musique du film : celle du modèle d'office (une musique de fin de film), modifiable ou retirable ; elle est appliquée à la vidéo dès l'ouverture du Studio.
  MontageMusic? _music;
  bool _listening = false;

  /// Musiques de fin de film proposées d'un geste (identifiants de `kStudioTracks`).
  static const _quick = ['eternal_hope', 'reign', 'noble_race', 'egmont_overture_finale', 'evening', 'continue_life', 'inspired', 'magistar', 'truth_of_the_legend', 'long_road_ahead', 'despair_and_triumph'];

  AppColors get _c => AppColors.of(context);

  int get _n => _photos.length < 2 ? 2 : _photos.length;   // le diaporama veut 2 images au moins : une seule photo est répétée
  double get _maxSeconds => _n * 10.0 - (_n - 1) * 0.5;
  double get _per => ((_seconds + (_n - 1) * 0.5) / _n).clamp(3.0, 10.0).toDouble();
  double get _total => _n * _per - (_n - 1) * 0.5;

  @override
  void initState() {
    super.initState();
    final def = studioTrack(widget.template.music);
    if (def != null) _music = MontageMusic.free(def);
    Future(() async {
      const assets = ['assets/images/intro2.jpg', 'assets/images/intro1.jpg', 'assets/images/intro6.jpg', 'assets/images/intro3.jpg', 'assets/images/intro7.jpg'];
      final out = [for (final a in assets) (await rootBundle.load(a)).buffer.asUint8List()];
      if (mounted) setState(() => _samples = out);
    });
    _redraw();
  }

  @override
  void dispose() {
    MontageMusicPlayer.stop();   // jamais de musique qui continue après la sortie de la page
    _anim.dispose();
    _text.dispose();
    super.dispose();
  }

  List<String> get _lines => _text.text.split('\n');

  /// Les musiques proposées d'un geste : celle du sujet d'abord, puis les musiques de fin de film.
  List<String> get _quickIds => {if (creditsSubjectFor(widget.template.id)?.music case final m?) m, ..._quick}.toList();

  /// Change le style du générique : le texte du sujet est réécrit pour ce style. Si la personne a modifié le texte, on le lui demande d'abord.
  Future<void> _setStyle(CreditsStyle s) async {
    if (s == _style) return;
    final edited = _text.text.trim() != creditsDefaultLinesFor(widget.template.id, style: _style).join('\n').trim();
    if (edited) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.tr('Changer de style ?')),
          content: Text(ctx.tr('Ton texte sera remplacé par celui de ce style.')),
          actions: [
            TextButton(key: const ValueKey('credits_style_keep'), onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.tr('Garder mon texte'))),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.tr('Changer'))),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    _text.text = creditsDefaultLinesFor(widget.template.id, style: s).join('\n');
    _style = s;
    _seconds = s.seconds.clamp(12.0, _maxSeconds).toDouble();
    await _redraw();
  }

  Future<void> _pickMusic(MontageMusic? m) async {
    await MontageMusicPlayer.stop();
    if (!mounted) return;
    setState(() {
      _music = m;
      _listening = false;
    });
  }

  Future<void> _toggleListen() async {
    final m = _music;
    if (m == null) return;
    if (_listening) {
      await MontageMusicPlayer.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    setState(() => _listening = true);
    final ok = await MontageMusicPlayer.play(m);
    if (!mounted) return;
    setState(() => _listening = ok);
    if (!ok) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Impossible de lire ce son. Vérifie ta connexion.'))));
  }

  Future<void> _changeMusic() async {
    await MontageMusicPlayer.stop();
    if (!mounted) return;
    setState(() => _listening = false);
    final pick = await showMontageMusicPicker(context, current: _music, onArtistCta: () {});
    if (pick == null || !mounted) return;
    setState(() => _music = pick.music);
  }

  /// Redessine le texte de l'aperçu et relance la montée.
  Future<void> _redraw() async {
    final png = await CreditsRender.png(_lines, width: 360);
    if (!mounted) return;
    setState(() {
      _credits = png;
      _creditsH = CreditsRender.heightFor(_lines, width: 360) + 360 * (16 / 9) * .24;
      _seconds = _seconds.clamp(12.0, _maxSeconds).toDouble();
    });
    _restart();
  }

  void _restart() {
    _anim
      ..stop()
      ..duration = Duration(milliseconds: (_total * 1000).round())
      ..repeat();
  }

  Future<void> _addPhotos() async {
    final room = 5 - _photos.length;
    if (room <= 0) return;
    final picked = await ImagePicker().pickMultiImage(imageQuality: 88, maxWidth: 1600, maxHeight: 1600, limit: room < 2 ? 2 : room);
    if (!mounted) return;
    for (final x in picked.take(room)) {
      // toute image prise dans la galerie passe le contrôle d'authenticité, comme partout
      if (!await AuthenticVideoCheck.gateImage(context, x.path, allowClaim: false) || !mounted) continue;
      _bytes[x.path] = await x.readAsBytes();
      _photos.add(x);
    }
    if (mounted) {
      setState(() => _seconds = _seconds.clamp(12.0, _maxSeconds).toDouble());
      _restart();
    }
  }

  /// La photo de fond au temps [t] (0 à 1 du film) : les photos se suivent, chacune pendant sa part du film.
  Uint8List? _bg(double t) {
    final list = _photos.isEmpty ? _samples : [for (final p in _photos) _bytes[p.path]!];
    if (list.isEmpty) return null;
    return list[(t * list.length).floor().clamp(0, list.length - 1)];
  }

  Future<File?> _render() async {
    setState(() {
      _busy = true;
      _busyLabel = context.tr('Préparation des images…');
    });
    final ids = <String>[];
    final photos = [for (final p in _photos) _bytes[p.path]!];
    final bgs = photos.length == 1 ? [photos.first, photos.first] : photos;
    for (final b in bgs) {
      final png = await StoryRender.png(const StoryAct(text: '', tone: StoryTone.dark), photo: b);   // la photo en plein cadre sous un voile sombre : le texte reste lisible
      ids.add(await ArgentUpload.bytes(png, contentType: 'image/png'));
    }
    final text = await CreditsRender.png(_lines, width: 720);
    final textId = await ArgentUpload.bytes(text, contentType: 'image/png');
    if (!mounted) return null;
    setState(() => _busyLabel = context.tr('Montage du générique…'));
    final res = await StudioSlideshowApi.render(
      {'uploads': ids, 'durations': List.filled(ids.length, _per), 'transition': 'fade', 'format': 'story', 'max_seconds': 60, 'scroll_upload': textId},
      idempotencyKey: 'credits:${const Uuid().v4()}',
    );
    final url = '${res['url']}';
    final r = await http.get(Uri.parse(url));
    if (r.statusCode != 200) throw ApiException(status: r.statusCode, code: 'download_failed', message: 'Téléchargement impossible');
    final dir = await getTemporaryDirectory();
    return File('${dir.path}/generique_${DateTime.now().microsecondsSinceEpoch}.mp4').writeAsBytes(r.bodyBytes);
  }

  Future<void> _create() async {
    if (_busy || _photos.isEmpty) return;
    try {
      final video = await _render();
      if (!mounted) return;
      setState(() => _busy = false);
      if (video == null) return;
      await MontageMusicPlayer.stop();
      PostTemplateLink.set(TemplateRef.fromStudioId(widget.template.id)?.code);   // le post comptera une utilisation et affichera « Essayer ce modèle »
      final r = await Navigator.of(context).push<String>(MaterialPageRoute(
        builder: (_) => CreateEditorPage(path: video.path, isVideo: true, source: PostSourceLink.imported, showSignature: true, sound: _music, autoFinish: true),
      ));
      if (r == kCreateDone && mounted) {
        Navigator.of(context).pop(kCreateDone);
      } else {
        PostTemplateLink.clear();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        handleApiError(context, e, onRetry: _create, fallback: context.tr('Le montage a échoué. Réessaie.'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(backgroundColor: c.surface, foregroundColor: c.textPrimary, title: Text(widget.template.name, style: const TextStyle(fontWeight: FontWeight.w800))),
      body: Stack(children: [
        ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 120), children: [
          Text(context.tr('Comme la fin d\'un film : ton texte monte lentement sur tes photos, puis « FIN ». Écris ton générique, une ligne par rôle.'), style: TextStyle(color: c.textSecondary, height: 1.35)),
          const SizedBox(height: 14),
          // aperçu : EXACTEMENT ce que la vidéo montrera (photos qui changent, texte qui monte, même durée)
          Center(
            child: SizedBox(
              width: 220,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: AnimatedBuilder(
                    animation: _anim,
                    builder: (_, __) {
                      final t = _anim.value;
                      final bg = _bg(t);
                      return Stack(fit: StackFit.expand, children: [
                        const ColoredBox(color: Colors.black),
                        if (bg != null) Image.memory(bg, fit: BoxFit.cover, gaplessPlayback: true, color: const Color(0xB3000000), colorBlendMode: BlendMode.darken),
                        if (_credits != null)
                          LayoutBuilder(builder: (_, box) {
                            // y = H − (H + h) × t : le texte entre par le bas et sort par le haut, comme sur le serveur
                            final imgH = _creditsH * box.maxWidth / 360;
                            final y = box.maxHeight - (box.maxHeight + imgH) * t;
                            return Stack(clipBehavior: Clip.hardEdge, children: [Positioned(left: 0, right: 0, top: y, height: imgH, child: Image.memory(_credits!, fit: BoxFit.fill, gaplessPlayback: true))]);
                          }),
                        if (_photos.isEmpty)
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: Colors.black.withValues(alpha: .65), borderRadius: BorderRadius.circular(8)), child: Text(context.tr('Photos d\'exemple'), style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800))),
                          ),
                      ]);
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(context.tr('Style du générique'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, children: [
            for (final s in CreditsStyle.values) ChoiceChip(key: ValueKey('credits_style_${s.name}'), label: Text(context.tr(s.label)), selected: _style == s, onSelected: (_) => _setStyle(s)),
          ]),
          const SizedBox(height: 4),
          Text(context.tr(_style.hint), style: TextStyle(color: c.textSecondary, fontSize: 12)),
          if (_style == CreditsStyle.chapitres && _maxSeconds < _style.seconds)
            Padding(padding: const EdgeInsets.only(top: 2), child: Text(context.tr('La version longue est plus belle avec 4 photos ou plus.'), style: TextStyle(color: c.accentText, fontSize: 12))),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('credits_text'),
            controller: _text,
            minLines: 8,
            maxLines: 14,
            style: TextStyle(color: c.textPrimary, height: 1.35),
            decoration: InputDecoration(labelText: context.tr('Ton générique'), helperText: context.tr('« # Titre » pour un grand titre · « Rôle · Nom » pour une ligne de générique'), helperMaxLines: 2, border: const OutlineInputBorder()),
            onChanged: (_) => _redraw(),
          ),
          const SizedBox(height: 4),
          Text(context.tr('Musique de fin de film'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border)),
            child: Row(children: [
              const Text('🎵', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(_music == null ? context.tr('Sans musique') : _music!.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700)),
              ),
              if (_music != null)
                IconButton(key: const ValueKey('credits_listen'), tooltip: context.tr('Écouter'), onPressed: _toggleListen, icon: Icon(_listening ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded, color: c.accentText, size: 30)),
              TextButton(key: const ValueKey('credits_music_change'), onPressed: _changeMusic, child: Text(context.tr('Changer'))),
            ]),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (final id in _quickIds)
                if (studioTrack(id) != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      key: ValueKey('credits_quick_$id'),
                      label: Text(studioTrack(id)!.title),
                      selected: _music?.id == id,
                      onSelected: (_) => _pickMusic(MontageMusic.free(studioTrack(id)!)),
                    ),
                  ),
              Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(key: const ValueKey('credits_no_music'), label: Text(context.tr('Sans musique')), selected: _music == null, onSelected: (_) => _pickMusic(null))),
            ]),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Text('${context.tr('Durée')} : ${_total.toStringAsFixed(0)} s', style: TextStyle(color: c.textPrimary)),
            Expanded(
              child: Slider(
                key: const ValueKey('credits_seconds'),
                value: _seconds.clamp(12.0, _maxSeconds).toDouble(),
                min: 12,
                max: _maxSeconds < 13 ? 13 : _maxSeconds,
                onChanged: (v) => setState(() => _seconds = v),
                onChangeEnd: (_) => _restart(),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Text(context.tr('Tes photos ({n}/5)', {'n': '${_photos.length}'}), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          SizedBox(
            height: 76,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (var i = 0; i < _photos.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Stack(children: [
                    ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(_bytes[_photos[i].path]!, width: 76, height: 76, fit: BoxFit.cover, cacheWidth: 200)),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _bytes.remove(_photos[i].path);
                          _photos.removeAt(i);
                          _seconds = _seconds.clamp(12.0, _maxSeconds).toDouble();
                          _restart();
                        }),
                        child: const CircleAvatar(radius: 11, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 14, color: Colors.white)),
                      ),
                    ),
                  ]),
                ),
              if (_photos.length < 5)
                InkWell(
                  key: const ValueKey('credits_add_photo'),
                  onTap: _addPhotos,
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(border: Border.all(color: c.border), borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.add_photo_alternate_rounded, color: c.textSecondary),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 6),
          Text(context.tr('Les photos changent pendant que le texte monte. Ajoute au moins une photo pour créer la vidéo.'), style: TextStyle(color: c.textSecondary, fontSize: 12)),
        ]),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: SafeArea(
            child: FilledButton(
              key: const ValueKey('credits_create'),
              onPressed: _busy || _photos.isEmpty ? null : _create,
              style: FilledButton.styleFrom(backgroundColor: c.primary, foregroundColor: Colors.black, minimumSize: const Size.fromHeight(50)),
              child: Text(_photos.isEmpty ? context.tr('Ajoute au moins une photo') : context.tr('Créer la vidéo 🎬'), style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ),
        if (_busy)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black54,
              child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const CircularProgressIndicator(), const SizedBox(height: 12), Text(_busyLabel, style: const TextStyle(color: Colors.white))])),
            ),
          ),
      ]),
    );
  }
}
