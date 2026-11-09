import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../l10n/tr.dart';
import '../../../services/authentic_video_check.dart';
import '../../../services/post_source_link.dart';
import '../../../services/template_link.dart';
import '../../../theme/app_colors.dart';
import '../../create/create_editor_page.dart';
import '../../create/create_result.dart';
import 'collage_template.dart';
import 'montage_catalog.dart';

/// Modèle « collage » : une photo par case (2 à 5 selon le modèle), étiquettes et titre modifiables ; le collage est ensuite repris par l'éditeur habituel (texte, musique, effets, widgets).
class CollageTemplatePage extends StatefulWidget {
  const CollageTemplatePage({super.key, required this.template, required this.script});
  final MontageTemplate template;
  final CollageScript script;

  @override
  State<CollageTemplatePage> createState() => _CollageTemplatePageState();
}

class _CollageTemplatePageState extends State<CollageTemplatePage> {
  late final List<Uint8List?> _photos = List.filled(widget.script.slots, null);
  late final List<TextEditingController> _labels = [for (final l in widget.script.labels) TextEditingController(text: l)];
  late final TextEditingController _caption = TextEditingController(text: widget.script.caption);
  bool _busy = false;
  Uint8List? _preview;

  AppColors get _c => AppColors.of(context);
  bool get _ready => _photos.every((p) => p != null);

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    for (final c in _labels) {
      c.dispose();
    }
    _caption.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final got = [for (final p in _photos) p ?? Uint8List(0)];
    // les cases vides restent sombres (octets vides : illisibles) ; l'aperçu montre déjà les étiquettes et le titre
    final png = await CollageTemplateRender.png(got, widget.script, labels: [for (final c in _labels) c.text], caption: _caption.text, width: 540);
    if (mounted) setState(() => _preview = png);
  }

  Future<void> _pick(int i) async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 88, maxWidth: 1600, maxHeight: 1600);
    if (x == null || !mounted) return;
    // toute image prise dans la galerie passe le contrôle d'authenticité, comme partout
    if (!await AuthenticVideoCheck.gateImage(context, x.path, allowClaim: false) || !mounted) return;
    _photos[i] = await x.readAsBytes();
    await _refresh();
  }

  Future<void> _create() async {
    if (_busy || !_ready) return;
    setState(() => _busy = true);
    try {
      final png = await CollageTemplateRender.png([for (final p in _photos) p!], widget.script, labels: [for (final c in _labels) c.text], caption: _caption.text);
      final f = await CollageTemplateRender.toFile(png);
      if (!mounted) return;
      PostTemplateLink.set(TemplateRef.fromStudioId(widget.template.id)?.code);   // le post comptera une utilisation et affichera « Essayer ce modèle »
      final r = await Navigator.of(context).push<String>(MaterialPageRoute(
        builder: (_) => CreateEditorPage(path: f.path, isVideo: false, source: PostSourceLink.imported, showSignature: true),
      ));
      if (r == kCreateDone && mounted) {
        Navigator.of(context).pop(kCreateDone);
      } else {
        PostTemplateLink.clear();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final n = widget.script.slots;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(backgroundColor: c.surface, foregroundColor: c.textPrimary, title: Text(widget.template.name, style: const TextStyle(fontWeight: FontWeight.w800))),
      body: Stack(children: [
        ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 110), children: [
          Text(context.tr('Choisis {n} photos, une par case. Tu peux changer les étiquettes et le titre.', {'n': '$n'}), style: TextStyle(color: c.textSecondary, height: 1.35)),
          const SizedBox(height: 12),
          Center(
            child: SizedBox(
              width: 240,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(aspectRatio: 4 / 5, child: _preview == null ? ColoredBox(color: c.border) : Image.memory(_preview!, fit: BoxFit.cover, gaplessPlayback: true)),
              ),
            ),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < n; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                InkWell(
                  key: ValueKey('collage_pick_$i'),
                  onTap: () => _pick(i),
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(border: Border.all(color: c.border), borderRadius: BorderRadius.circular(10)),
                    child: _photos[i] == null
                        ? Icon(Icons.add_photo_alternate_rounded, color: c.textSecondary)
                        : ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(_photos[i]!, fit: BoxFit.cover, cacheWidth: 200)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    key: ValueKey('collage_label_$i'),
                    controller: _labels[i],
                    maxLength: 14,
                    style: TextStyle(color: c.textPrimary),
                    decoration: InputDecoration(labelText: context.tr('Étiquette de la photo {n}', {'n': '${i + 1}'}), counterText: '', border: const OutlineInputBorder(), isDense: true),
                    onChanged: (_) => _refresh(),
                  ),
                ),
              ]),
            ),
          TextField(
            key: const ValueKey('collage_caption'),
            controller: _caption,
            maxLength: 50,
            style: TextStyle(color: c.textPrimary),
            decoration: InputDecoration(labelText: context.tr('Titre'), border: const OutlineInputBorder()),
            onChanged: (_) => _refresh(),
          ),
        ]),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: SafeArea(
            child: FilledButton(
              key: const ValueKey('collage_create'),
              onPressed: _busy || !_ready ? null : _create,
              style: FilledButton.styleFrom(backgroundColor: c.primary, foregroundColor: Colors.black, minimumSize: const Size.fromHeight(50)),
              child: Text(_ready ? context.tr('Continuer') : context.tr('Choisis les {n} photos', {'n': '$n'}), style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ),
      ]),
    );
  }
}
