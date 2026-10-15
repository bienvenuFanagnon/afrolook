// lib/pages/studio/studio_models.dart

import 'dart:io';

/// Types de contenu créables dans le Studio
enum StudioContentType { text, image, video, audio }

/// Résultat produit par le Studio — transmis à la page de post/chronique
class StudioResult {
  final StudioContentType type;
  final File? mediaFile;        // image, vidéo ou audio
  final File? coverImageFile;   // pochette audio ou fond texte
  final String? textContent;
  final String? backgroundColor;
  final String? templateId;
  final bool forChronique;      // true = chronique 9/16, false = post
  final int? audioStartMs;      // début du clip (trim), en millisecondes
  final int? audioEndMs;        // fin du clip (trim), en millisecondes

  const StudioResult({
    required this.type,
    this.mediaFile,
    this.coverImageFile,
    this.textContent,
    this.backgroundColor,
    this.templateId,
    this.forChronique = false,
    this.audioStartMs,
    this.audioEndMs,
  });
}

/// Définition d'un template Studio
class StudioTemplate {
  final String id;
  final String name;
  final String emoji;
  final StudioContentType type;
  final String? backgroundColor;
  final String? overlayColor;   // couleur de l'overlay teinté sur la photo/vidéo
  final double overlayOpacity;
  final String? category;       // Situation, Émotion, Afrique, Fête…
  final bool requiresPhoto;     // ce template attend une photo user

  const StudioTemplate({
    required this.id,
    required this.name,
    required this.emoji,
    required this.type,
    this.backgroundColor,
    this.overlayColor,
    this.overlayOpacity = 0.4,
    this.category,
    this.requiresPhoto = false,
  });
}

// ─── Catalogue de templates ────────────────────────────────────────────────

const List<StudioTemplate> kStudioTemplates = [
  // ── Texte simple ──
  StudioTemplate(id: 'txt_quote', name: 'Citation', emoji: '💬', type: StudioContentType.text, backgroundColor: '#1a0a2a', category: 'Texte'),
  StudioTemplate(id: 'txt_annonce', name: 'Annonce', emoji: '📢', type: StudioContentType.text, backgroundColor: '#0a1a0a', category: 'Texte'),
  StudioTemplate(id: 'txt_humeur', name: 'Humeur du jour', emoji: '😌', type: StudioContentType.text, backgroundColor: '#1a1a2a', category: 'Texte'),
  StudioTemplate(id: 'txt_pensee', name: 'Pensée', emoji: '🤔', type: StudioContentType.text, backgroundColor: '#0a0a1a', category: 'Texte'),

  // ── Image + Texte (requiresPhoto) ──
  StudioTemplate(id: 'img_fauche', name: 'Fauché 😭', emoji: '💸', type: StudioContentType.image, overlayColor: '#000000', overlayOpacity: 0.55, category: 'Situation', requiresPhoto: true),
  StudioTemplate(id: 'img_amoureux', name: 'Amoureux 💕', emoji: '❤️', type: StudioContentType.image, overlayColor: '#2a0a1a', overlayOpacity: 0.5, category: 'Situation', requiresPhoto: true),
  StudioTemplate(id: 'img_riche', name: "Plein d'argent 🤑", emoji: '💰', type: StudioContentType.image, overlayColor: '#0a1a0a', overlayOpacity: 0.45, category: 'Situation', requiresPhoto: true),
  StudioTemplate(id: 'img_celibataire', name: 'Célibataire 😤', emoji: '🚫', type: StudioContentType.image, overlayColor: '#1a1a1a', overlayOpacity: 0.5, category: 'Situation', requiresPhoto: true),
  StudioTemplate(id: 'img_fiance', name: 'Fiancé 💍', emoji: '💍', type: StudioContentType.image, overlayColor: '#1a0a1a', overlayOpacity: 0.45, category: 'Situation', requiresPhoto: true),
  StudioTemplate(id: 'img_en_feu', name: 'En Feu 🔥', emoji: '🔥', type: StudioContentType.image, overlayColor: '#2a0a0a', overlayOpacity: 0.5, category: 'Émotion', requiresPhoto: true),
  StudioTemplate(id: 'img_good_vibes', name: 'Good Vibes ✨', emoji: '✨', type: StudioContentType.image, overlayColor: '#0a1a0a', overlayOpacity: 0.4, category: 'Émotion', requiresPhoto: true),
  StudioTemplate(id: 'img_zen', name: 'Zen 🧘', emoji: '🧘', type: StudioContentType.image, overlayColor: '#0a0a2a', overlayOpacity: 0.4, category: 'Émotion', requiresPhoto: true),
  StudioTemplate(id: 'img_queen', name: 'Queen Mode 👑', emoji: '👑', type: StudioContentType.image, overlayColor: '#1a0a2a', overlayOpacity: 0.45, category: 'Émotion', requiresPhoto: true),
  StudioTemplate(id: 'img_togo', name: 'Togolais 🇹🇬', emoji: '🇹🇬', type: StudioContentType.image, overlayColor: '#006B3F', overlayOpacity: 0.35, category: 'Afrique', requiresPhoto: true),
  StudioTemplate(id: 'img_ci', name: "Ivoirien 🇨🇮", emoji: '🇨🇮', type: StudioContentType.image, overlayColor: '#F77F00', overlayOpacity: 0.35, category: 'Afrique', requiresPhoto: true),
  StudioTemplate(id: 'img_sn', name: 'Sénégalais 🇸🇳', emoji: '🇸🇳', type: StudioContentType.image, overlayColor: '#00853F', overlayOpacity: 0.35, category: 'Afrique', requiresPhoto: true),
  StudioTemplate(id: 'img_marche', name: 'Au marché 🛒', emoji: '🛒', type: StudioContentType.image, overlayColor: '#2a1a0a', overlayOpacity: 0.5, category: 'Afrique', requiresPhoto: true),
  StudioTemplate(id: 'img_boite', name: 'Boîte de nuit 🎶', emoji: '🎶', type: StudioContentType.image, overlayColor: '#1a0a1a', overlayOpacity: 0.55, category: 'Afrique', requiresPhoto: true),
  StudioTemplate(id: 'img_anniv', name: 'Anniversaire 🎂', emoji: '🎂', type: StudioContentType.image, overlayColor: '#1a0a0a', overlayOpacity: 0.45, category: 'Fête', requiresPhoto: true),
  StudioTemplate(id: 'img_noel', name: 'Joyeux Noël 🎄', emoji: '🎄', type: StudioContentType.image, overlayColor: '#0a1a0a', overlayOpacity: 0.4, category: 'Fête', requiresPhoto: true),
  StudioTemplate(id: 'img_an', name: 'Bonne Année 🎊', emoji: '🎊', type: StudioContentType.image, overlayColor: '#1a0a0a', overlayOpacity: 0.45, category: 'Fête', requiresPhoto: true),
  StudioTemplate(id: 'img_indep_tg', name: 'Indép. Togo 🇹🇬', emoji: '🇹🇬', type: StudioContentType.image, overlayColor: '#006B3F', overlayOpacity: 0.4, category: 'Fête', requiresPhoto: true),

  // ── Vidéo + Texte (requiresPhoto = false ici, mais on demande une vidéo) ──
  StudioTemplate(id: 'vid_vlog', name: 'Mon Vlog 📹', emoji: '📹', type: StudioContentType.video, backgroundColor: '#0a0a12', category: 'Vidéo'),
  StudioTemplate(id: 'vid_defi', name: 'Défi 🔴', emoji: '🔴', type: StudioContentType.video, backgroundColor: '#0a0a12', category: 'Vidéo'),
  StudioTemplate(id: 'vid_story', name: 'Story 15s', emoji: '📱', type: StudioContentType.video, backgroundColor: '#0a0a12', category: 'Vidéo'),

  // ── Audio + Texte ──
  StudioTemplate(id: 'aud_podcast', name: 'Podcast', emoji: '🎙️', type: StudioContentType.audio, backgroundColor: '#1a0a2a', category: 'Audio'),
  StudioTemplate(id: 'aud_ambiance', name: 'Son Ambiance', emoji: '🎵', type: StudioContentType.audio, backgroundColor: '#0a1a0a', category: 'Audio'),
  StudioTemplate(id: 'aud_vocal', name: 'Message Vocal', emoji: '🎤', type: StudioContentType.audio, backgroundColor: '#1a1a0a', category: 'Audio'),
];
