import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../l10n/tr.dart';
import '../../models/model_data.dart';
import '../../theme/app_colors.dart';
import '../studio/studio_models.dart';
import 'create_flow.dart';
import 'create_result.dart';

/// Fonds proposés pour le papier : dégradés profonds, lisibles avec un texte blanc (les mêmes couleurs que la proposition « Parcours de création »).
const List<List<Color>> kTextPapers = [
  [Color(0xFF7A2E1F), Color(0xFF3C1F4A)],
  [Color(0xFF1F7A4F), Color(0xFF0F3D3A)],
  [Color(0xFF244B8F), Color(0xFF14284F)],
  [Color(0xFFB07A12), Color(0xFF5C3A0A)],
  [Color(0xFF454B52), Color(0xFF1D2024)],
];

/// Façons d'écrire : changent seulement l'allure du texte sur le papier.
const List<({String id, String label, double size, FontWeight weight, FontStyle style})> kTextStyles = [
  (id: 'quote', label: 'Citation', size: 25, weight: FontWeight.w700, style: FontStyle.italic),
  (id: 'announce', label: 'Annonce', size: 30, weight: FontWeight.w900, style: FontStyle.normal),
  (id: 'mood', label: 'Humeur', size: 28, weight: FontWeight.w800, style: FontStyle.normal),
  (id: 'thought', label: 'Pensée', size: 24, weight: FontWeight.w600, style: FontStyle.italic),
];

/// Écran « Écrire » du parcours « Créer un post » (type Texte de la proposition) : un papier de couleur avec le texte au centre, des pastilles de couleurs et des façons d'écrire.
/// « Suivant » transforme le papier en image et ouvre le formulaire unique, avec le texte déjà dans la description.
class CreateTextPage extends StatefulWidget {
  const CreateTextPage({super.key, this.canal, this.defiPostId, this.openForm});

  final Canal? canal;
  final String? defiPostId;

  /// Remplace l'ouverture du formulaire (tests) : reçoit le fichier image du papier et le texte.
  final Future<String> Function(File image, String text)? openForm;

  @override
  State<CreateTextPage> createState() => _CreateTextPageState();
}

class _CreateTextPageState extends State<CreateTextPage> {
  final _text = TextEditingController();
  final _paperKey = GlobalKey();
  int _paper = 0;
  int _style = 0;
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<File> _render() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    final boundary = _paperKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await boundary.toImage(pixelRatio: 3);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    final dir = await getTemporaryDirectory();
    return File('${dir.path}/texte_${DateTime.now().microsecondsSinceEpoch}.png').writeAsBytes(data!.buffer.asUint8List(), flush: true);
  }

  Future<void> _next() async {
    final text = _text.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Écris ton texte avant de continuer.'))));
      return;
    }
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final file = await _render();
      if (!mounted) return;
      final String r;
      if (widget.openForm != null) {
        r = await widget.openForm!(file, text);
      } else {
        r = await openCreateForm(context, studio: StudioResult(type: StudioContentType.image, mediaFile: file, textContent: text), canal: widget.canal, defiPostId: widget.defiPostId);
      }
      if (!mounted) return;
      if (r == kCreateDone) Navigator.of(context).pop(kCreateDone);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Impossible de préparer le texte. Réessaie.'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final st = kTextStyles[_style];
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        foregroundColor: c.textPrimary,
        centerTitle: true,
        leading: IconButton(key: const ValueKey('text_close'), icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(context).pop(kCreateBack)),
        title: Text(context.tr('Texte'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        actions: [
          TextButton(
            key: const ValueKey('text_next'),
            onPressed: _busy ? null : _next,
            child: Text(context.tr('Suivant'), style: TextStyle(color: c.accentText, fontWeight: FontWeight.w800, fontSize: 16)),
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
        RepaintBoundary(
          key: _paperKey,
          child: AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: kTextPapers[_paper])),
              padding: const EdgeInsets.all(22),
              alignment: Alignment.center,
              child: TextField(
                key: const ValueKey('text_field'),
                controller: _text,
                maxLength: 300,
                maxLines: null,
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.sentences,
                cursorColor: Colors.white,
                onChanged: (_) => setState(() {}),
                style: TextStyle(color: Colors.white, fontSize: st.size, fontWeight: st.weight, fontStyle: st.style, height: 1.25),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  counterText: '',
                  hintText: context.tr('Écris ton texte…'),
                  hintStyle: TextStyle(color: const Color(0x99FFFFFF), fontSize: st.size, fontWeight: st.weight, fontStyle: st.style),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < kTextPapers.length; i++)
            GestureDetector(
              key: ValueKey('text_paper_$i'),
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _paper = i);
              },
              child: Container(
                width: 34,
                height: 34,
                margin: const EdgeInsets.symmetric(horizontal: 7),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: kTextPapers[i]),
                  border: Border.all(color: _paper == i ? c.textPrimary : c.border, width: _paper == i ? 2.5 : 1),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 16),
        Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
          for (var i = 0; i < kTextStyles.length; i++)
            GestureDetector(
              key: ValueKey('text_style_${kTextStyles[i].id}'),
              onTap: () => setState(() => _style = i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(color: _style == i ? c.accent : c.surfaceVariant, borderRadius: BorderRadius.circular(99), border: Border.all(color: _style == i ? c.accent : c.border)),
                child: Text(context.tr(kTextStyles[i].label), style: TextStyle(color: _style == i ? c.onAccent : c.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w700)),
              ),
            ),
        ]),
      ]),
    );
  }
}
