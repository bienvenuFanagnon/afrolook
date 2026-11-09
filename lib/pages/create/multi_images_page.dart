import 'dart:io';

import 'package:afrolook_api_client/afrolook_api_client.dart' show ApiException;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../l10n/tr.dart';
import '../../models/model_data.dart';
import '../../services/api/api_gateway.dart';
import '../../services/api/argent_upload.dart';
import '../../services/api/wallet_api.dart';
import '../../services/authentic_video_check.dart';
import '../../services/collage_layouts.dart';
import '../../services/post_source_link.dart';
import '../../theme/app_colors.dart';
import '../../widgets/api_error_dialogs.dart';
import '../studio/montage/montage_catalog.dart';
import '../studio/montage/montage_editor_page.dart';
import '../studio/studio_models.dart';
import 'create_editor_page.dart';
import 'create_flow.dart';
import 'create_result.dart';

enum _Mode { carousel, collage, slideshow }

/// « Mes images » : le lot de 2 à 5 images choisi dans la galerie, avec trois façons de le publier (maquette validée le 08/11) :
/// - **Carrousel** : chaque image se retouche seule (Studio), on change l'ordre, on en ajoute ou retire ; publié comme un post à plusieurs images ;
/// - **Collage** : les images sont collées dans UNE image (mises en page selon le nombre d'images, espace réglable) ;
/// - **Diaporama** : les images deviennent une vidéo (durée, transition) assemblée par le serveur ; la musique et le reste se règlent ensuite dans l'éditeur vidéo.
class MultiImagesPage extends StatefulWidget {
  const MultiImagesPage({super.key, required this.paths, this.canal, this.defiPostId});

  final List<String> paths;
  final Canal? canal;
  final String? defiPostId;

  @override
  State<MultiImagesPage> createState() => _MultiImagesPageState();
}

class _MultiImagesPageState extends State<MultiImagesPage> {
  late final List<String> _paths = List.of(widget.paths);
  final Set<String> _edited = {};   // images retouchées dans le Studio (mention « Fait sur Afrolook »)
  int _sel = 0;
  _Mode _mode = _Mode.carousel;
  String? _layout;
  double _gap = 0;
  double _seconds = 3;
  String _transition = 'fade';
  String _format = 'story';
  bool _busy = false;
  String _busyLabel = '';

  String get _activeLayout {
    final ok = CollageLayouts.forCount(_paths.length);
    return _layout != null && ok.contains(_layout) ? _layout! : ok.first;
  }

  void _say(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  // ── Lot d'images ────────────────────────────────────────────────────────

  Future<void> _add() async {
    final room = CollageLayouts.maxImages - _paths.length;
    if (room <= 0) {
      _say(context.tr('5 images au plus.'));
      return;
    }
    final xs = await ImagePicker().pickMultiImage(maxWidth: 1600, imageQuality: 92, limit: room);
    if (xs.isEmpty || !mounted) return;
    for (final x in xs.take(room)) {
      // comme toute image de la galerie : refusée si elle vient d'un autre réseau ou si elle est explicite
      if (!await AuthenticVideoCheck.gateImage(context, x.path, allowClaim: false) || !mounted) continue;
      setState(() => _paths.add(x.path));
    }
  }

  void _remove(int i) {
    if (_paths.length <= CollageLayouts.minImages) {
      _say(context.tr('2 images au moins.'));
      return;
    }
    setState(() {
      _edited.remove(_paths[i]);
      _paths.removeAt(i);
      _sel = _sel.clamp(0, _paths.length - 1);
    });
  }

  Future<void> _retouch() async {
    final path = _paths[_sel];
    final StudioResult? r = await Navigator.of(context).push<StudioResult>(MaterialPageRoute(builder: (_) => MontageEditorPage(template: kPlainTemplate, presetPhotoPath: path, photoOnly: true)));   // une image de carrousel reste une image : pas de musique
    final f = r?.mediaFile;
    if (r == null || f == null || !mounted) return;
    setState(() {
      _edited.remove(path);
      _paths[_sel] = f.path;
      _edited.add(f.path);
    });
  }

  // ── Sortie ──────────────────────────────────────────────────────────────

  Future<void> _next() async {
    if (_busy) return;
    try {
      switch (_mode) {
        case _Mode.carousel:
          final bytes = [for (final p in _paths) await File(p).readAsBytes()];
          final r = await openCreateForm(context, kind: CreatePostKind.image, images: bytes, canal: widget.canal, defiPostId: widget.defiPostId, source: _edited.isNotEmpty ? PostSourceLink.edited : PostSourceLink.imported);
          _finish(r);
        case _Mode.collage:
          _setBusy(context.tr('Assemblage du collage…'));
          final file = await CollageLayouts.render(_paths, _activeLayout, gap: _gap);
          _setBusy(null);
          if (!mounted) return;
          final r = await openCreateForm(context, studio: StudioResult(type: StudioContentType.image, mediaFile: file), canal: widget.canal, defiPostId: widget.defiPostId, source: PostSourceLink.edited);
          _finish(r);
        case _Mode.slideshow:
          final video = await _renderSlideshow();
          if (video == null || !mounted) return;
          // la vidéo s'ouvre dans l'éditeur habituel : musique, texte, effets, puis publication
          final r = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => CreateEditorPage(path: video.path, isVideo: true, source: PostSourceLink.edited, canal: widget.canal, defiPostId: widget.defiPostId)));
          if (r == kCreateRedo || r == null) return;
          _finish(r);
      }
    } catch (e) {
      _setBusy(null);
      if (mounted) handleApiError(context, e, onRetry: _next, fallback: context.tr('Le montage a échoué. Réessaie.'));
    }
  }

  void _finish(String r) {
    if (r == kCreateDone && mounted) Navigator.of(context).pop(kCreateDone);
  }

  void _setBusy(String? label) {
    if (!mounted) return;
    setState(() {
      _busy = label != null;
      _busyLabel = label ?? '';
    });
  }

  Future<File?> _renderSlideshow() async {
    _setBusy(context.tr('Envoi des images…'));
    final ids = <String>[];
    for (final p in _paths) {
      final bytes = await File(p).readAsBytes();
      ids.add(await ArgentUpload.bytes(bytes, contentType: ArgentUpload.sniffImageType(bytes, path: p)));   // type réel du contenu, pas celui de l'extension
    }
    _setBusy(context.tr('Montage du diaporama…'));
    final res = await ApiGateway.instance.client.post('/studio/slideshow', body: {'uploads': ids, 'seconds': _seconds, 'transition': _transition, 'format': _format}, idempotencyKey: 'slideshow:${const Uuid().v4()}', longJob: true);
    final url = '${WalletApi.map(res)['url']}';
    _setBusy(context.tr('Téléchargement…'));
    final r = await http.get(Uri.parse(url));
    if (r.statusCode != 200) throw ApiException(status: r.statusCode, code: 'download_failed', message: 'Téléchargement impossible');
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/slideshow_${DateTime.now().microsecondsSinceEpoch}.mp4');
    await f.writeAsBytes(r.bodyBytes);
    _setBusy(null);
    return f;
  }

  Future<void> _leave() async {
    if (_busy) return;
    final c = AppColors.of(context);
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text(context.tr('Quitter le montage ?'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
        content: Text(context.tr('Les changements faits sur ces images seront perdus.'), style: TextStyle(color: c.textSecondary)),
        actions: [
          TextButton(key: const ValueKey('multi_stay'), onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('Continuer le montage'))),
          TextButton(key: const ValueKey('multi_leave'), onPressed: () => Navigator.pop(ctx, true), child: Text(context.tr('Quitter'), style: TextStyle(color: c.danger))),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.of(context).pop(kCreateBack);
  }

  // ── Écran ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(children: [
            Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 12, 0),
                child: Row(children: [
                  _round(const ValueKey('multi_back'), Icons.chevron_left_rounded, _leave),
                  Expanded(child: Center(child: Text('${context.tr('Mes images')} · ${_paths.length} / ${CollageLayouts.maxImages}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)))),
                  const SizedBox(width: 40),
                ]),
              ),
              Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(20, 10, 20, 8), child: _preview())),
              _strip(c),
              const SizedBox(height: 8),
              _modeChips(c),
              Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: _options(c)),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Row(children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: FilledButton(
                        key: const ValueKey('multi_redo'),
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
                      height: 48,
                      child: FilledButton(
                        key: const ValueKey('multi_next'),
                        onPressed: _busy ? null : _next,
                        style: FilledButton.styleFrom(backgroundColor: c.accent, foregroundColor: c.onAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                        child: Text(context.tr('Suivant'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      ),
                    ),
                  ),
                ]),
              ),
            ]),
            if (_busy)
              Positioned.fill(
                child: ColoredBox(
                  color: const Color(0xAA000000),
                  child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const CircularProgressIndicator(color: Color(0xFFFFC400)),
                      const SizedBox(height: 14),
                      Text(_busyLabel, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _round(Key key, IconData icon, VoidCallback onTap) => GestureDetector(
        key: key,
        onTap: onTap,
        child: Container(width: 40, height: 40, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x66000000)), child: Icon(icon, color: Colors.white, size: 24)),
      );

  /// Aperçu : l'image choisie dans son format réel (carrousel, diaporama) ou le collage tel qu'il sera.
  Widget _preview() {
    switch (_mode) {
      case _Mode.collage:
        return Center(child: AspectRatio(aspectRatio: CollageLayouts.aspect, child: CollagePreview(paths: _paths, layout: _activeLayout, gap: _gap)));
      case _Mode.carousel:
      case _Mode.slideshow:
        return Center(child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(_paths[_sel]), key: ValueKey('multi_preview_${_paths[_sel]}'), fit: BoxFit.contain)));
    }
  }

  /// Rangée de vignettes : touche pour choisir, croix pour retirer, appui long puis glisser pour changer l'ordre, « + » pour en ajouter.
  Widget _strip(AppColors c) {
    return SizedBox(
      height: 84,
      child: Row(children: [
        Expanded(
          child: ReorderableListView.builder(
            key: const ValueKey('multi_strip'),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            buildDefaultDragHandles: true,
            itemCount: _paths.length,
            proxyDecorator: (child, _, __) => Material(color: Colors.transparent, child: child),
            onReorder: (a, b) => setState(() {
              if (b > a) b--;
              final p = _paths.removeAt(a);
              _paths.insert(b, p);
              _sel = b;
            }),
            itemBuilder: (context, i) {
              final selected = i == _sel;
              return GestureDetector(
                key: ValueKey('thumb_${_paths[i]}'),
                onTap: () => setState(() => _sel = i),
                child: Padding(
                  padding: const EdgeInsets.only(right: 8, top: 8, bottom: 4),
                  child: Stack(clipBehavior: Clip.none, children: [
                    Container(
                      width: 52,
                      height: 68,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: selected ? const Color(0xFF2ECC71) : Colors.white24, width: selected ? 2.5 : 1)),
                      child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(_paths[i]), fit: BoxFit.cover, cacheWidth: 160)),
                    ),
                    Positioned(
                      top: -6,
                      right: -6,
                      child: GestureDetector(
                        key: ValueKey('remove_$i'),
                        onTap: () => _remove(i),
                        child: Container(width: 20, height: 20, decoration: BoxDecoration(color: const Color(0xFF222222), shape: BoxShape.circle, border: Border.all(color: Colors.white54)), child: const Icon(Icons.close_rounded, color: Colors.white, size: 13)),
                      ),
                    ),
                  ]),
                ),
              );
            },
          ),
        ),
        if (_paths.length < CollageLayouts.maxImages)
          Padding(
            padding: const EdgeInsets.only(right: 14, top: 8, bottom: 4),
            child: GestureDetector(
              key: const ValueKey('multi_add'),
              onTap: _add,
              child: Container(
                width: 52,
                height: 68,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white38, width: 1.5)),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _modeChips(AppColors c) {
    Widget chip(_Mode m, String label, IconData icon) {
      final sel = _mode == m;
      return Expanded(
        child: GestureDetector(
          key: ValueKey('mode_${m.name}'),
          onTap: () => setState(() => _mode = m),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(color: sel ? const Color(0xFF2ECC71) : Colors.white.withOpacity(.07), borderRadius: BorderRadius.circular(12), border: Border.all(color: sel ? const Color(0xFF2ECC71) : Colors.white24)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 16, color: sel ? const Color(0xFF04210F) : Colors.white),
              const SizedBox(width: 5),
              Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: sel ? const Color(0xFF04210F) : Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5))),
            ]),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(children: [
        chip(_Mode.carousel, context.tr('Carrousel'), Icons.view_carousel_rounded),
        chip(_Mode.collage, context.tr('Collage'), Icons.grid_view_rounded),
        chip(_Mode.slideshow, context.tr('Diaporama'), Icons.slideshow_rounded),
      ]),
    );
  }

  Widget _options(AppColors c) {
    const white = TextStyle(color: Colors.white, fontSize: 13);
    switch (_mode) {
      case _Mode.carousel:
        return Row(children: [
          Expanded(child: Text(context.tr('Touche une image pour la retoucher, glisse pour changer l\'ordre.'), style: TextStyle(color: Colors.white.withOpacity(.7), fontSize: 12.5))),
          const SizedBox(width: 8),
          OutlinedButton.icon(key: const ValueKey('multi_retouch'), onPressed: _retouch, icon: const Icon(Icons.auto_fix_high_rounded, size: 18), label: Text(context.tr('Retoucher')), style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white38))),
        ]);
      case _Mode.collage:
        return Column(mainAxisSize: MainAxisSize.min, children: [
          Wrap(spacing: 8, runSpacing: 2, children: [
            for (final id in CollageLayouts.forCount(_paths.length))
              ChoiceChip(key: ValueKey('layout_$id'), label: Text(context.tr(CollageLayouts.labels[id] ?? id)), selected: _activeLayout == id, onSelected: (_) => setState(() => _layout = id)),
          ]),
          Row(children: [
            Text(context.tr('Espace'), style: white),
            Expanded(child: Slider(key: const ValueKey('collage_gap'), value: _gap, min: 0, max: .04, onChanged: (v) => setState(() => _gap = v))),
          ]),
        ]);
      case _Mode.slideshow:
        return Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Text('${context.tr('Durée par image')} : ${_seconds.toStringAsFixed(0)} s', style: white),
            Expanded(child: Slider(key: const ValueKey('slide_seconds'), value: _seconds, min: 2, max: 5, divisions: 3, onChanged: (v) => setState(() => _seconds = v))),
          ]),
          Wrap(spacing: 8, runSpacing: 2, children: [
            for (final e in [('fade', 'Fondu'), ('slide', 'Glissé'), ('zoom', 'Zoom'), ('none', 'Coupe')])
              ChoiceChip(key: ValueKey('trans_${e.$1}'), label: Text(context.tr(e.$2)), selected: _transition == e.$1, onSelected: (_) => setState(() => _transition = e.$1)),
            for (final e in [('story', '9:16'), ('post', '4:5'), ('landscape', '16:9')])
              ChoiceChip(key: ValueKey('fmt_${e.$1}'), label: Text(e.$2), selected: _format == e.$1, onSelected: (_) => setState(() => _format = e.$1)),
          ]),
        ]);
    }
  }
}

/// Aperçu du collage : les mêmes cases que le rendu final, chaque image remplit sa case (recadrée au centre).
class CollagePreview extends StatelessWidget {
  const CollagePreview({super.key, required this.paths, required this.layout, required this.gap});

  final List<String> paths;
  final String layout;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final cells = CollageLayouts.withGap(CollageLayouts.cells0(layout, paths.length), gap);
    return LayoutBuilder(builder: (context, box) {
      return Stack(children: [
        const Positioned.fill(child: ColoredBox(color: Color(0xFF111111))),
        for (var i = 0; i < paths.length && i < cells.length; i++)
          Positioned.fromRect(
            rect: Rect.fromLTWH(cells[i].left * box.maxWidth, cells[i].top * box.maxHeight, cells[i].width * box.maxWidth, cells[i].height * box.maxHeight),
            child: Image.file(File(paths[i]), key: ValueKey('cell_${paths[i]}_$i'), fit: BoxFit.cover, cacheWidth: 600),
          ),
      ]);
    });
  }
}
