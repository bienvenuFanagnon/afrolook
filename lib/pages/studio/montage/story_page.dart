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
import 'montage_catalog.dart';
import 'story_render.dart';
import 'story_script.dart';

/// Modèle « histoire » (09/11/2026) : la vidéo défile toute seule, acte après acte. La personne choisit jusqu'à 5 photos (les actes les utilisent à tour de rôle), peut réécrire chaque phrase
/// et régler le temps de chaque acte ; le serveur assemble le tout (diaporama) puis l'éditeur habituel propose musique, effets et publication.
class StoryTemplatePage extends StatefulWidget {
  const StoryTemplatePage({super.key, required this.template, required this.script});
  final MontageTemplate template;
  final StoryScript script;

  @override
  State<StoryTemplatePage> createState() => _StoryTemplatePageState();
}

class _StoryTemplatePageState extends State<StoryTemplatePage> {
  late final List<StoryAct> _acts =List.of(widget.script.acts);
  final List<XFile> _photos = [];
  final Map<String, Uint8List> _bytes = {};
  int _sel = 0;
  bool _playing = false;
  List<Uint8List> _samples = const [];   // photos d'exemple de l'application : seulement pour l'aperçu, jamais dans la vidéo créée
  bool _busy = false;
  String _busyLabel = '';
  late final List<TextEditingController> _ctrls = [for (final a in _acts) TextEditingController(text: a.text)];

  AppColors get _c => AppColors.of(context);

  @override
  void initState() {
    super.initState();
    Future(() async {
      final assets = [widget.template.sample, 'assets/images/intro1.jpg', 'assets/images/intro3.jpg', 'assets/images/intro6.jpg', 'assets/images/intro7.jpg'];
      final out = [for (final a in assets) (await rootBundle.load(a)).buffer.asUint8List()];
      if (mounted) setState(() => _samples = out);
    });
  }

  /// Joue toute l'histoire dans l'aperçu, scène après scène, avec le vrai temps de chaque scène : ce que la vidéo montrera.
  Future<void> _play() async {
    if (_playing) {
      setState(() => _playing = false);
      return;
    }
    setState(() {
      _playing = true;
      _sel = 0;
    });
    for (var i = 0; i < _acts.length; i++) {
      if (!mounted || !_playing) return;
      setState(() => _sel = i);
      await Future<void>.delayed(Duration(milliseconds: (_acts[i].seconds * 1000).round()));
    }
    if (mounted) setState(() => _playing = false);
  }

  @override
  void dispose() {
    _playing = false;
    for (final c in _ctrls) {
      c.dispose();
    }
    super.dispose();
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
    if (mounted) setState(() {});
  }

  Uint8List? _photoFor(StoryAct a) {
    if (_photos.isEmpty) return _samples.isEmpty ? null : _samples[a.photo % _samples.length];   // aperçu seulement
    return _bytes[_photos[a.photo % _photos.length].path];
  }

  double get _total => _acts.fold(0.0, (s, a) => s + a.seconds);

  Future<File?> _render() async {
    setState(() {
      _busy = true;
      _busyLabel = context.tr('Préparation des images…');
    });
    final ids = <String>[];
    for (final a in _acts) {
      final png = await StoryRender.png(a, photo: _photos.isEmpty ? null : _photoFor(a));
      ids.add(await ArgentUpload.bytes(png, contentType: 'image/png'));
    }
    if (!mounted) return null;
    setState(() => _busyLabel = context.tr('Montage de l\'histoire…'));
    final res = await StudioSlideshowApi.render(
      {'uploads': ids, 'durations': [for (final a in _acts) a.seconds], 'transition': widget.script.transition, 'format': 'story', 'max_seconds': 60},
      idempotencyKey: 'story:${const Uuid().v4()}',
    );
    final url = '${res['url']}';
    final r = await http.get(Uri.parse(url));
    if (r.statusCode != 200) throw ApiException(status: r.statusCode, code: 'download_failed', message: 'Téléchargement impossible');
    final dir = await getTemporaryDirectory();
    return File('${dir.path}/histoire_${DateTime.now().microsecondsSinceEpoch}.mp4').writeAsBytes(r.bodyBytes);
  }

  Future<void> _create() async {
    if (_busy) return;
    try {
      final video = await _render();
      if (!mounted) return;
      setState(() => _busy = false);
      if (video == null) return;
      PostTemplateLink.set(TemplateRef.fromStudioId(widget.template.id)?.code);   // le post affichera « Essayer ce modèle » et comptera une utilisation
      final r = await Navigator.of(context).push<String>(MaterialPageRoute(
        builder: (_) => CreateEditorPage(path: video.path, isVideo: true, source: _photos.isEmpty ? PostSourceLink.edited : PostSourceLink.imported, showSignature: true),
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
    final act = _acts[_sel];
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(backgroundColor: c.surface, foregroundColor: c.textPrimary, title: Text(widget.template.name, style: const TextStyle(fontWeight: FontWeight.w800))),
      body: Stack(children: [
        ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 120), children: [
          Text(
            context.tr('Une vidéo qui défile toute seule : {n} scènes, {s} secondes. Change les photos et les phrases comme tu veux.', {'n': '${_acts.length}', 's': _total.toStringAsFixed(0)}),
            style: TextStyle(color: c.textSecondary, height: 1.35),
          ),
          const SizedBox(height: 14),
          // aperçu de la scène choisie : le même dessin que le fichier envoyé
          Center(
            child: SizedBox(
              width: 220,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: StoryRender.ratio,
                  child: FutureBuilder<Uint8List>(
                    key: ValueKey('story_preview_${_sel}_${act.text}_${act.photo}_${_photos.length}'),
                    future: StoryRender.png(act, photo: _photoFor(act), width: 360),
                    builder: (_, s) => Stack(fit: StackFit.expand, children: [
                      s.hasData ? Image.memory(s.data!, fit: BoxFit.cover, gaplessPlayback: true) : ColoredBox(color: c.border),
                      if (_photos.isEmpty)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: Colors.black.withValues(alpha: .65), borderRadius: BorderRadius.circular(8)), child: Text(context.tr('Photos d\'exemple'), style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800))),
                        ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 38,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (var i = 0; i < _acts.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    key: ValueKey('story_act_$i'),
                    label: Text('${i + 1}'),
                    selected: _sel == i,
                    onSelected: (_) => setState(() => _sel = i),
                  ),
                ),
            ]),
          ),
          Center(
            child: TextButton.icon(
              key: const ValueKey('story_play'),
              onPressed: _play,
              icon: Icon(_playing ? Icons.stop_rounded : Icons.play_arrow_rounded),
              label: Text(_playing ? context.tr('Arrêter') : context.tr('Voir le film')),
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            key: const ValueKey('story_text'),
            controller: _ctrls[_sel],
            maxLength: 90,
            maxLines: 2,
            style: TextStyle(color: c.textPrimary),
            decoration: InputDecoration(labelText: context.tr('Phrase de la scène {n}', {'n': '${_sel + 1}'}), border: const OutlineInputBorder()),
            onChanged: (v) => setState(() => _acts[_sel] = _acts[_sel].copyWith(text: v)),
          ),
          Row(children: [
            Text('${context.tr('Durée')} : ${act.seconds.toStringAsFixed(1)} s', style: TextStyle(color: c.textPrimary)),
            Expanded(
              child: Slider(
                key: const ValueKey('story_seconds'),
                value: act.seconds.clamp(1.5, 8.0),
                min: 1.5,
                max: 8,
                divisions: 13,
                onChanged: (v) => setState(() => _acts[_sel] = _acts[_sel].copyWith(seconds: v)),
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
                        }),
                        child: const CircleAvatar(radius: 11, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 14, color: Colors.white)),
                      ),
                    ),
                  ]),
                ),
              if (_photos.length < 5)
                InkWell(
                  key: const ValueKey('story_add_photo'),
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
          Text(context.tr('Les photos passent à tour de rôle dans les scènes. Ajoute au moins une photo pour créer la vidéo.'), style: TextStyle(color: c.textSecondary, fontSize: 12)),
        ]),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: SafeArea(
            child: FilledButton(
              key: const ValueKey('story_create'),
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
