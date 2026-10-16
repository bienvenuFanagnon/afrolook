// lib/pages/studio/studio_entry_page.dart
//
// Point d'entrée du Studio Afrolook.
// Reçoit [forChronique] : true = ratio 9/16, durées chronique.
// Retourne un [StudioResult] via Navigator.pop().

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'studio_models.dart';
import 'studio_text_editor.dart';
import 'studio_image_editor.dart';
import 'studio_video_editor.dart';
import 'studio_audio_editor.dart';
import 'montage/montage_gallery_page.dart';
import 'montage/montage_music.dart';
import '../music/music_page.dart';

const _c = AppColors.dark;

class StudioEntryPage extends StatelessWidget {
  final bool forChronique;

  const StudioEntryPage({Key? key, this.forChronique = false}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _c.background,
      appBar: AppBar(
        backgroundColor: _c.background,
        elevation: 0,
        title: const Text(
          'Studio Afrolook',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          if (forChronique)
            Container(
              margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: _c.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: _c.primary.withOpacity(0.4)),
              ),
              child: const Text('Chronique', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Que voulez-vous créer ?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _c.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choisissez un type de contenu pour commencer',
                style: TextStyle(fontSize: 13, color: _c.textSecondary),
              ),
              const SizedBox(height: 18),
              _TemplatesBanner(onTap: () => _openTemplates(context)),
              const SizedBox(height: 10),
              _ArtistStrip(onTap: () => openArtistSpace(context)),
              const SizedBox(height: 10),
              _MusicStrip(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MusicPage()))),
              const SizedBox(height: 16),
              Text(
                'Ou crée librement',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _c.textSecondary),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  childAspectRatio: 1.1,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  children: [
                    _TypeCard(
                      emoji: '✏️',
                      label: 'Texte simple',
                      sublabel: 'Citation, annonce, humeur',
                      color: _c.primary,
                      onTap: () => _openEditor(context, StudioContentType.text),
                    ),
                    _TypeCard(
                      emoji: '📸',
                      label: 'Image + Texte',
                      sublabel: 'Ta photo + filtre + texte',
                      color: const Color(0xFF4ECDC4),
                      onTap: () => _openEditor(context, StudioContentType.image),
                    ),
                    _TypeCard(
                      emoji: '🎥',
                      label: 'Vidéo + Texte',
                      sublabel: 'Enregistrer ou galerie',
                      color: const Color(0xFFE84B3C),
                      onTap: () => _openEditor(context, StudioContentType.video),
                    ),
                    _TypeCard(
                      emoji: '🎙️',
                      label: 'Audio + Texte',
                      sublabel: 'Son + pochette optionnelle',
                      color: const Color(0xFF9B59B6),
                      onTap: () => _openEditor(context, StudioContentType.audio),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openTemplates(BuildContext context) async {
    final result = await Navigator.push<StudioResult>(
      context,
      MaterialPageRoute(builder: (_) => MontageGalleryPage(forChronique: forChronique)),
    );
    if (result != null && context.mounted) Navigator.pop(context, result);
  }

  Future<void> _openEditor(BuildContext context, StudioContentType type) async {
    StudioResult? result;

    switch (type) {
      case StudioContentType.text:
        result = await Navigator.push<StudioResult>(
          context,
          MaterialPageRoute(
            builder: (_) => StudioTextEditor(forChronique: forChronique),
          ),
        );
        break;
      case StudioContentType.image:
        result = await Navigator.push<StudioResult>(
          context,
          MaterialPageRoute(
            builder: (_) => StudioImageEditor(forChronique: forChronique),
          ),
        );
        break;
      case StudioContentType.video:
        result = await Navigator.push<StudioResult>(
          context,
          MaterialPageRoute(
            builder: (_) => StudioVideoEditor(forChronique: forChronique),
          ),
        );
        break;
      case StudioContentType.audio:
        result = await Navigator.push<StudioResult>(
          context,
          MaterialPageRoute(
            builder: (_) => StudioAudioEditor(forChronique: forChronique),
          ),
        );
        break;
    }

    if (result != null && context.mounted) {
      Navigator.pop(context, result);
    }
  }
}

/// Accès à la page Musique (écouter, aimer, créer avec un titre).
class _MusicStrip extends StatelessWidget {
  const _MusicStrip({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: _c.surface, border: Border.all(color: _c.border)),
        child: Row(children: [
          const Text('🎧', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Page Musique', style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.w800, fontSize: 13.5)),
              const SizedBox(height: 2),
              Text('Écoute, mets en favoris et crée avec un titre.', style: TextStyle(color: _c.textSecondary, fontSize: 11.5)),
            ]),
          ),
          Icon(Icons.chevron_right_rounded, color: _c.textSecondary),
        ]),
      ),
    );
  }
}

/// Accès visible à l'espace artiste : déposer ses sons et gagner des pièces à chaque utilisation dans le Studio.
class _ArtistStrip extends StatelessWidget {
  const _ArtistStrip({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(colors: [Color(0xFF6A1B9A), Color(0xFFE91E63)]),
        ),
        child: const Row(children: [
          Text('🎤', style: TextStyle(fontSize: 24)),
          SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Tu es artiste ? Propose ton son', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5)),
              SizedBox(height: 2),
              Text('Gagne des pièces à chaque fois qu’il est utilisé dans le Studio.', style: TextStyle(color: Color(0xE6FFFFFF), fontSize: 11.5)),
            ]),
          ),
          Icon(Icons.chevron_right_rounded, color: Colors.white),
        ]),
      ),
    );
  }
}

class _TemplatesBanner extends StatelessWidget {
  const _TemplatesBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(colors: [Color(0xFF1FAA59), Color(0xFF0F6B38)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: Row(children: [
          SizedBox(
            width: 104,
            height: 64,
            child: Stack(children: [
              for (var i = 0; i < 3; i++)
                Positioned(
                  left: i * 30.0,
                  child: Container(
                    width: 42,
                    height: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white, width: 1.5),
                      image: DecorationImage(image: AssetImage('assets/images/intro${[7, 6, 3][i]}.jpg'), fit: BoxFit.cover),
                    ),
                  ),
                ),
            ]),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('✨ Templates prêts à poster', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
              SizedBox(height: 3),
              Text('53 modèles déjà remplis, avec musique : émotions, Insta, situations, pays, fêtes. Photo ou vidéo.',
                  style: TextStyle(color: Color(0xDDFFFFFF), fontSize: 12, height: 1.3)),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: Colors.white),
        ]),
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final String emoji;
  final String label;
  final String sublabel;
  final Color color;
  final VoidCallback onTap;

  const _TypeCard({
    required this.emoji,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.4)),
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _c.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sublabel,
              style: TextStyle(fontSize: 11, color: _c.textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
