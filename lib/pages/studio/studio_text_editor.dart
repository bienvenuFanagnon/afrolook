// lib/pages/studio/studio_text_editor.dart

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'studio_models.dart';

// Raccourci palette sombre fixe pour le Studio (toujours dark)
const _c = AppColors.dark;

class StudioTextEditor extends StatefulWidget {
  final bool forChronique;
  const StudioTextEditor({Key? key, this.forChronique = false}) : super(key: key);

  @override
  State<StudioTextEditor> createState() => _StudioTextEditorState();
}

class _StudioTextEditorState extends State<StudioTextEditor> {
  final _textController = TextEditingController();
  StudioTemplate? _selectedTemplate;
  String _selectedBg = '#1a0a2a';

  static const List<Map<String, String>> _bgColors = [
    {'label': 'Violet nuit', 'color': '#1a0a2a'},
    {'label': 'Vert forêt', 'color': '#0a1a0a'},
    {'label': 'Bleu nuit', 'color': '#0a0a1a'},
    {'label': 'Rouge sombre', 'color': '#1a0a0a'},
    {'label': 'Ambre', 'color': '#1a1200'},
    {'label': 'Gris foncé', 'color': '#1a1a1a'},
  ];

  List<StudioTemplate> get _textTemplates =>
      kStudioTemplates.where((t) => t.type == StudioContentType.text).toList();

  @override
  void initState() {
    super.initState();
    _selectedTemplate = _textTemplates.first;
    _selectedBg = _selectedTemplate!.backgroundColor ?? '#1a0a2a';
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Color _hexToColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _c.background,
      appBar: AppBar(
        backgroundColor: _c.background,
        elevation: 0,
        title: const Text('Texte', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          TextButton(
            onPressed: _canPublish ? _publish : null,
            child: Text(
              'Suivant →',
              style: TextStyle(
                color: _canPublish ? _c.primary : _c.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Aperçu
          Expanded(
            flex: 5,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _hexToColor(_selectedBg),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: _textController.text.isEmpty
                      ? Text(
                          'Votre texte ici…',
                          style: TextStyle(
                            fontSize: 22,
                            color: Colors.white.withOpacity(0.3),
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        )
                      : Text(
                          _textController.text,
                          style: const TextStyle(
                            fontSize: 22,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                ),
              ),
            ),
          ),

          // Templates
          SizedBox(
            height: 80,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _textTemplates.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final t = _textTemplates[i];
                final sel = _selectedTemplate?.id == t.id;
                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedTemplate = t;
                    _selectedBg = t.backgroundColor ?? '#1a0a2a';
                  }),
                  child: Container(
                    width: 70,
                    decoration: BoxDecoration(
                      color: sel
                          ? _c.primary.withOpacity(0.2)
                          : _c.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: sel ? _c.primary : _c.border,
                        width: sel ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(t.emoji, style: const TextStyle(fontSize: 20)),
                        const SizedBox(height: 4),
                        Text(
                          t.name,
                          style: TextStyle(
                            fontSize: 9,
                            color: sel ? _c.primary : _c.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          // Couleurs de fond
          SizedBox(
            height: 36,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _bgColors.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final c = _bgColors[i];
                final sel = _selectedBg == c['color'];
                return GestureDetector(
                  onTap: () => setState(() => _selectedBg = c['color']!),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _hexToColor(c['color']!),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: sel ? _c.primary : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: sel
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          // Saisie texte
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: _c.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _c.border),
            ),
            child: TextField(
              controller: _textController,
              maxLines: 3,
              maxLength: widget.forChronique ? 200 : 500,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 14, color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Écrivez votre message…',
                hintStyle: TextStyle(color: _c.textSecondary),
                border: InputBorder.none,
                counterStyle: TextStyle(color: _c.textSecondary, fontSize: 10),
              ),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  bool get _canPublish => _textController.text.trim().isNotEmpty;

  void _publish() {
    Navigator.pop(
      context,
      StudioResult(
        type: StudioContentType.text,
        textContent: _textController.text.trim(),
        backgroundColor: _selectedBg,
        templateId: _selectedTemplate?.id,
        forChronique: widget.forChronique,
      ),
    );
  }
}
