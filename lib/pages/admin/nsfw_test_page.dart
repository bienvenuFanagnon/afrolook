import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/nsfw_check.dart';
import '../../theme/app_colors.dart';

/// Écran de réglage du filtre de contenu explicite (équipe de modération) : on choisit une image et on voit les 5 scores du modèle gratuit du téléphone
/// et la décision qu'il prendrait. Sert à vérifier le filtre sur de vrais exemples avant de s'y fier, et à régler les seuils (NsfwCheck.strongPorn / mediumPorn).
/// Aucune image n'est envoyée nulle part.
class NsfwTestPage extends StatefulWidget {
  const NsfwTestPage({super.key});

  @override
  State<NsfwTestPage> createState() => _NsfwTestPageState();
}

class _NsfwTestPageState extends State<NsfwTestPage> {
  final _picker = ImagePicker();
  File? _file;
  List<double>? _scores;
  bool _busy = false;
  String? _error;

  Future<void> _pick() async {
    final x = await _picker.pickImage(source: ImageSource.gallery);
    if (x == null) return;
    setState(() {
      _file = File(x.path);
      _scores = null;
      _busy = true;
      _error = null;
    });
    final s = await NsfwCheck.score(x.path);
    if (!mounted) return;
    setState(() {
      _scores = s;
      _busy = false;
      _error = s == null ? 'Le modèle n\'a pas pu tourner sur cette image.' : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = _scores;
    final blocked = s != null && NsfwCheck.decide([s]);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(backgroundColor: c.background, foregroundColor: c.textPrimary, elevation: 0, title: const Text('Essai du filtre de contenu', style: TextStyle(fontWeight: FontWeight.w800))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(
          'Choisis une image : le modèle gratuit du téléphone donne un score pour chaque classe. Seule « porn » bloque (≥ ${NsfwCheck.strongPorn} sur une image) ; « sexy » passe. Rien n\'est envoyé.',
          style: TextStyle(color: c.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: _busy ? null : _pick, icon: const Icon(Icons.image_outlined), label: const Text('Choisir une image')),
        const SizedBox(height: 14),
        if (_file != null) ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.file(_file!, height: 240, fit: BoxFit.cover)),
        if (_busy) const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: TextStyle(color: c.danger))),
        if (s != null) ...[
          const SizedBox(height: 14),
          for (var i = 0; i < NsfwCheck.labels.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                SizedBox(width: 78, child: Text(NsfwCheck.labels[i], style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700))),
                Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: s[i].clamp(0.0, 1.0), minHeight: 10, backgroundColor: c.border, color: i == NsfwCheck.iPorn ? c.danger : c.accent))),
                SizedBox(width: 48, child: Text(s[i].toStringAsFixed(2), textAlign: TextAlign.right, style: TextStyle(color: c.textSecondary))),
              ]),
            ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: (blocked ? c.danger : c.success).withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: Text(blocked ? 'Décision : BLOQUÉ (contenu explicite)' : 'Décision : accepté', style: TextStyle(color: blocked ? c.danger : c.success, fontWeight: FontWeight.w800)),
          ),
        ],
      ]),
    );
  }
}
