// lib/pages/studio/studio_image_editor.dart
//
// Éditeur image du Studio : l'utilisateur choisit d'abord un template/filtre,
// puis prend une photo ou en sélectionne une. L'overlay du template est rendu
// par-dessus sa photo. Il peut modifier le texte d'accroche.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import '../../theme/app_colors.dart';
import 'studio_models.dart';

const _c = AppColors.dark;

class StudioImageEditor extends StatefulWidget {
  final bool forChronique;
  const StudioImageEditor({Key? key, this.forChronique = false}) : super(key: key);

  @override
  State<StudioImageEditor> createState() => _StudioImageEditorState();
}

class _StudioImageEditorState extends State<StudioImageEditor> {
  File? _imageFile;
  StudioTemplate? _selectedTemplate;
  final _captionController = TextEditingController();
  bool _isLoading = false;
  String? _selectedCategory;

  final _picker = ImagePicker();

  List<StudioTemplate> get _imageTemplates =>
      kStudioTemplates.where((t) => t.type == StudioContentType.image).toList();

  List<String> get _categories {
    final cats = _imageTemplates.map((t) => t.category ?? '').toSet().toList();
    cats.remove('');
    return ['Tous', ...cats];
  }

  List<StudioTemplate> get _filteredTemplates => _selectedCategory == null ||
          _selectedCategory == 'Tous'
      ? _imageTemplates
      : _imageTemplates.where((t) => t.category == _selectedCategory).toList();

  @override
  void initState() {
    super.initState();
    _selectedTemplate = _imageTemplates.first;
    _selectedCategory = 'Tous';
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Color _hexToColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final xfile = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 90,
      );
      if (xfile == null) return;

      setState(() => _isLoading = true);

      // Compression WebP
      final tmpDir = await getTemporaryDirectory();
      final outPath = '${tmpDir.path}/studio_img_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final compressed = await FlutterImageCompress.compressAndGetFile(
        xfile.path,
        outPath,
        quality: 85,
        format: CompressFormat.jpeg,
      );

      setState(() {
        _imageFile = compressed != null ? File(compressed.path) : File(xfile.path);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _c.background,
      appBar: AppBar(
        backgroundColor: _c.background,
        elevation: 0,
        title: const Text('Image + Texte', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          if (_imageFile != null)
            TextButton(
              onPressed: _publish,
              child: Text(
                'Suivant →',
                style: TextStyle(color: _c.primary, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Aperçu photo + overlay
          Expanded(
            flex: 5,
            child: GestureDetector(
              onTap: () => _showImageSourceSheet(context),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: _c.surface,
                  border: Border.all(color: _c.border),
                ),
                clipBehavior: Clip.hardEdge,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Photo ou placeholder
                    _imageFile != null
                        ? Image.file(_imageFile!, fit: BoxFit.cover)
                        : _PhotoPlaceholder(onTap: () => _showImageSourceSheet(context)),

                    // Overlay teinté du template
                    if (_selectedTemplate != null && _imageFile != null)
                      Container(
                        color: _hexToColor(_selectedTemplate!.overlayColor ?? '#000000')
                            .withOpacity(_selectedTemplate!.overlayOpacity),
                      ),

                    // Texte caption en bas
                    if (_captionController.text.isNotEmpty || _selectedTemplate != null)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [Color(0xDD000000), Colors.transparent],
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_selectedTemplate != null)
                                Row(
                                  children: [
                                    Text(
                                      _selectedTemplate!.emoji,
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _selectedTemplate!.name,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              if (_captionController.text.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _captionController.text,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                    // Loader
                    if (_isLoading)
                      Container(
                        color: Colors.black54,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Saisie caption
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: _c.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _c.border),
            ),
            child: TextField(
              controller: _captionController,
              maxLines: 1,
              maxLength: 80,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 13, color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Texte court (optionnel)…',
                hintStyle: TextStyle(color: _c.textSecondary),
                border: InputBorder.none,
                counterText: '',
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Catégories
          SizedBox(
            height: 32,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final cat = _categories[i];
                final sel = _selectedCategory == cat;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: sel ? _c.primary : _c.surface,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: sel ? _c.primary : _c.border,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      cat,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: sel ? Colors.black : _c.textSecondary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // Grille des templates
          SizedBox(
            height: 90,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _filteredTemplates.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final t = _filteredTemplates[i];
                final sel = _selectedTemplate?.id == t.id;
                return GestureDetector(
                  onTap: () => setState(() => _selectedTemplate = t),
                  child: Container(
                    width: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: sel ? _c.primary : _c.border,
                        width: sel ? 2 : 1,
                      ),
                      color: t.overlayColor != null
                          ? _hexToColor(t.overlayColor!).withOpacity(0.25)
                          : _c.surface,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(t.emoji, style: const TextStyle(fontSize: 22)),
                        const SizedBox(height: 3),
                        Text(
                          t.name,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: sel ? _c.primary : _c.textSecondary,
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

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showImageSourceSheet(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: _c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.white),
              title: const Text('Prendre une photo', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white),
              title: const Text('Choisir depuis la galerie', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _publish() {
    if (_imageFile == null) return;
    Navigator.pop(
      context,
      StudioResult(
        type: StudioContentType.image,
        mediaFile: _imageFile,
        textContent: _captionController.text.trim().isEmpty ? null : _captionController.text.trim(),
        templateId: _selectedTemplate?.id,
        forChronique: widget.forChronique,
      ),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  final VoidCallback onTap;
  const _PhotoPlaceholder({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: const Color(0xFF1A1F3A),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white24, width: 2),
                borderRadius: BorderRadius.circular(36),
              ),
              child: const Icon(Icons.camera_alt, color: Colors.white38, size: 32),
            ),
            const SizedBox(height: 12),
            const Text(
              'Toucher pour ajouter\nvotre photo',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
