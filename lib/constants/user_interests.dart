import 'package:flutter/material.dart';

class UserInterest {
  final String code;
  final String emoji;
  final String labelFr;
  final String labelEn;
  final String category;

  const UserInterest({
    required this.code,
    required this.emoji,
    required this.labelFr,
    required this.labelEn,
    required this.category,
  });

  String label(String locale) => locale.startsWith('en') ? labelEn : labelFr;
}

class InterestCategory {
  final String id;
  final String emoji;
  final String labelFr;

  const InterestCategory({required this.id, required this.emoji, required this.labelFr});
}

class UserInterests {
  static const List<InterestCategory> categories = [
    InterestCategory(id: 'music',         emoji: '🎵', labelFr: 'Musique'),
    InterestCategory(id: 'sport',         emoji: '⚽', labelFr: 'Sport'),
    InterestCategory(id: 'dance',         emoji: '💃', labelFr: 'Danse & Spectacle'),
    InterestCategory(id: 'fashion',       emoji: '👗', labelFr: 'Mode & Beauté'),
    InterestCategory(id: 'food',          emoji: '🍛', labelFr: 'Gastronomie'),
    InterestCategory(id: 'cinema',        emoji: '🎬', labelFr: 'Cinéma & Créativité'),
    InterestCategory(id: 'culture',       emoji: '📚', labelFr: 'Culture & Savoir'),
    InterestCategory(id: 'business',      emoji: '💼', labelFr: 'Business & Finance'),
    InterestCategory(id: 'lifestyle',     emoji: '🌍', labelFr: 'Lifestyle & Société'),
    InterestCategory(id: 'gaming',        emoji: '🎮', labelFr: 'Gaming & Tech'),
  ];

  static const List<UserInterest> all = [
    // ── Musique ──────────────────────────────────────────────────────────────
    UserInterest(code: 'music_afrobeat',    emoji: '🥁', labelFr: 'Afrobeat',       labelEn: 'Afrobeat',       category: 'music'),
    UserInterest(code: 'music_afropop',     emoji: '🎤', labelFr: 'Afropop',        labelEn: 'Afropop',        category: 'music'),
    UserInterest(code: 'music_hiphop',      emoji: '🎧', labelFr: 'Hip-Hop / Rap',  labelEn: 'Hip-Hop / Rap',  category: 'music'),
    UserInterest(code: 'music_rnb',         emoji: '🎶', labelFr: 'R&B / Soul',     labelEn: 'R&B / Soul',     category: 'music'),
    UserInterest(code: 'music_gospel',      emoji: '🙏', labelFr: 'Gospel',         labelEn: 'Gospel',         category: 'music'),
    UserInterest(code: 'music_coupedecale', emoji: '🕺', labelFr: "Coupé-Décalé",   labelEn: "Coupé-Décalé",   category: 'music'),
    UserInterest(code: 'music_ndombolo',    emoji: '🪘', labelFr: 'Ndombolo',       labelEn: 'Ndombolo',       category: 'music'),
    UserInterest(code: 'music_jazz',        emoji: '🎷', labelFr: 'Jazz',           labelEn: 'Jazz',           category: 'music'),
    UserInterest(code: 'music_reggae',      emoji: '🌿', labelFr: 'Reggae / Zouk',  labelEn: 'Reggae / Zouk',  category: 'music'),
    UserInterest(code: 'music_traditional', emoji: '🪗', labelFr: 'Musique Traditionnelle', labelEn: 'Traditional Music', category: 'music'),
    UserInterest(code: 'music_djing',       emoji: '🎚️', labelFr: 'DJ / Production', labelEn: 'DJ / Production', category: 'music'),

    // ── Sport ─────────────────────────────────────────────────────────────────
    UserInterest(code: 'sport_foot',        emoji: '⚽', labelFr: 'Football',       labelEn: 'Football',       category: 'sport'),
    UserInterest(code: 'sport_basket',      emoji: '🏀', labelFr: 'Basketball',     labelEn: 'Basketball',     category: 'sport'),
    UserInterest(code: 'sport_fitness',     emoji: '💪', labelFr: 'Fitness / Gym',  labelEn: 'Fitness / Gym',  category: 'sport'),
    UserInterest(code: 'sport_athletics',   emoji: '🏃', labelFr: 'Athlétisme',     labelEn: 'Athletics',      category: 'sport'),
    UserInterest(code: 'sport_combat',      emoji: '🥊', labelFr: 'Sports de Combat', labelEn: 'Combat Sports', category: 'sport'),
    UserInterest(code: 'sport_natation',    emoji: '🏊', labelFr: 'Natation',       labelEn: 'Swimming',       category: 'sport'),
    UserInterest(code: 'sport_tennis',      emoji: '🎾', labelFr: 'Tennis',         labelEn: 'Tennis',         category: 'sport'),
    UserInterest(code: 'sport_cyclisme',    emoji: '🚴', labelFr: 'Cyclisme',       labelEn: 'Cycling',        category: 'sport'),
    UserInterest(code: 'sport_esport',      emoji: '🕹️', labelFr: 'E-sport',        labelEn: 'Esports',        category: 'sport'),

    // ── Danse & Spectacle ────────────────────────────────────────────────────
    UserInterest(code: 'dance_afro',        emoji: '💃', labelFr: 'Danses Afro',    labelEn: 'Afro Dance',     category: 'dance'),
    UserInterest(code: 'dance_hip',         emoji: '🕺', labelFr: 'Hip-Hop Dance',  labelEn: 'Hip-Hop Dance',  category: 'dance'),
    UserInterest(code: 'dance_traditional', emoji: '🪘', labelFr: 'Danses Traditionnelles', labelEn: 'Traditional Dance', category: 'dance'),
    UserInterest(code: 'entertainment_comedy', emoji: '😂', labelFr: 'Humour / Sketchs', labelEn: 'Comedy / Sketchs', category: 'dance'),
    UserInterest(code: 'entertainment_standup', emoji: '🎙️', labelFr: 'Stand-Up',   labelEn: 'Stand-Up',       category: 'dance'),
    UserInterest(code: 'entertainment_theatre', emoji: '🎭', labelFr: 'Théâtre',    labelEn: 'Theatre',        category: 'dance'),

    // ── Mode & Beauté ─────────────────────────────────────────────────────────
    UserInterest(code: 'fashion_mode',      emoji: '👗', labelFr: 'Mode',           labelEn: 'Fashion',        category: 'fashion'),
    UserInterest(code: 'fashion_streetwear',emoji: '👟', labelFr: 'Streetwear',     labelEn: 'Streetwear',     category: 'fashion'),
    UserInterest(code: 'fashion_traditional',emoji:'🧣', labelFr: 'Mode Africaine', labelEn: 'African Fashion', category: 'fashion'),
    UserInterest(code: 'beauty_makeup',     emoji: '💄', labelFr: 'Maquillage',     labelEn: 'Makeup',         category: 'fashion'),
    UserInterest(code: 'beauty_skincare',   emoji: '✨', labelFr: 'Skincare / Soins', labelEn: 'Skincare',     category: 'fashion'),
    UserInterest(code: 'beauty_hair',       emoji: '💇', labelFr: 'Coiffure / Tresses', labelEn: 'Hair / Braids', category: 'fashion'),

    // ── Gastronomie ───────────────────────────────────────────────────────────
    UserInterest(code: 'food_cuisine',      emoji: '🍛', labelFr: 'Cuisine Africaine', labelEn: 'African Cuisine', category: 'food'),
    UserInterest(code: 'food_streetfood',   emoji: '🌮', labelFr: 'Street Food',    labelEn: 'Street Food',    category: 'food'),
    UserInterest(code: 'food_vegan',        emoji: '🥗', labelFr: 'Cuisine Végane / Bio', labelEn: 'Vegan / Organic', category: 'food'),
    UserInterest(code: 'food_patisserie',   emoji: '🍰', labelFr: 'Pâtisserie',     labelEn: 'Pastry',         category: 'food'),
    UserInterest(code: 'food_drinks',       emoji: '🥤', labelFr: 'Boissons & Cocktails', labelEn: 'Drinks & Cocktails', category: 'food'),
    UserInterest(code: 'food_recettes',     emoji: '👨‍🍳', labelFr: 'Recettes & DIY Cuisine', labelEn: 'Recipes & DIY Cooking', category: 'food'),

    // ── Cinéma & Créativité ───────────────────────────────────────────────────
    UserInterest(code: 'cinema_nollywood',  emoji: '🎬', labelFr: 'Nollywood / Séries Afro', labelEn: 'Nollywood / Afro Series', category: 'cinema'),
    UserInterest(code: 'cinema_film',       emoji: '🎞️', labelFr: 'Cinéma & Films', labelEn: 'Cinema & Films', category: 'cinema'),
    UserInterest(code: 'photo_video',       emoji: '📸', labelFr: 'Photo & Vidéo',  labelEn: 'Photo & Video',  category: 'cinema'),
    UserInterest(code: 'art_dessin',        emoji: '✏️', labelFr: 'Dessin & Illustration', labelEn: 'Drawing & Illustration', category: 'cinema'),
    UserInterest(code: 'art_peinture',      emoji: '🎨', labelFr: 'Peinture & Art', labelEn: 'Painting & Art', category: 'cinema'),
    UserInterest(code: 'art_sculpture',     emoji: '🗿', labelFr: 'Sculpture & Artisanat', labelEn: 'Sculpture & Craft', category: 'cinema'),
    UserInterest(code: 'art_animation',     emoji: '🎭', labelFr: 'Animation & Manga', labelEn: 'Animation & Manga', category: 'cinema'),

    // ── Culture & Savoir ──────────────────────────────────────────────────────
    UserInterest(code: 'culture_histoire',  emoji: '🏛️', labelFr: 'Histoire Africaine', labelEn: 'African History', category: 'culture'),
    UserInterest(code: 'culture_langue',    emoji: '🗣️', labelFr: 'Langues & Cultures', labelEn: 'Languages & Cultures', category: 'culture'),
    UserInterest(code: 'education_tech',    emoji: '💻', labelFr: 'Technologie & Innovation', labelEn: 'Technology & Innovation', category: 'culture'),
    UserInterest(code: 'education_science', emoji: '🔬', labelFr: 'Science & Nature', labelEn: 'Science & Nature', category: 'culture'),
    UserInterest(code: 'education_dev',     emoji: '👨‍💻', labelFr: 'Dev & Programmation', labelEn: 'Dev & Programming', category: 'culture'),
    UserInterest(code: 'education_sante',   emoji: '🏥', labelFr: 'Santé & Médecine', labelEn: 'Health & Medicine', category: 'culture'),
    UserInterest(code: 'education_juridique', emoji: '⚖️', labelFr: 'Droit & Justice', labelEn: 'Law & Justice',  category: 'culture'),

    // ── Business & Finance ────────────────────────────────────────────────────
    UserInterest(code: 'business_entrepreneuriat', emoji: '🚀', labelFr: 'Entrepreneuriat', labelEn: 'Entrepreneurship', category: 'business'),
    UserInterest(code: 'business_investissement',   emoji: '📈', labelFr: 'Investissement & Bourse', labelEn: 'Investment & Trading', category: 'business'),
    UserInterest(code: 'business_immobilier',       emoji: '🏠', labelFr: 'Immobilier', labelEn: 'Real Estate', category: 'business'),
    UserInterest(code: 'business_crypto',           emoji: '₿',  labelFr: 'Crypto & Web3', labelEn: 'Crypto & Web3', category: 'business'),
    UserInterest(code: 'business_ecommerce',        emoji: '🛒', labelFr: 'E-commerce & Vente', labelEn: 'E-commerce & Sales', category: 'business'),
    UserInterest(code: 'business_marketing',        emoji: '📢', labelFr: 'Marketing & Influence', labelEn: 'Marketing & Influence', category: 'business'),

    // ── Lifestyle & Société ───────────────────────────────────────────────────
    UserInterest(code: 'lifestyle_voyage',   emoji: '✈️', labelFr: 'Voyage & Tourisme', labelEn: 'Travel & Tourism', category: 'lifestyle'),
    UserInterest(code: 'lifestyle_nature',   emoji: '🌿', labelFr: 'Nature & Environnement', labelEn: 'Nature & Environment', category: 'lifestyle'),
    UserInterest(code: 'lifestyle_animaux',  emoji: '🐾', labelFr: 'Animaux & Pets', labelEn: 'Animals & Pets', category: 'lifestyle'),
    UserInterest(code: 'lifestyle_famille',  emoji: '👨‍👩‍👧', labelFr: 'Famille & Parentalité', labelEn: 'Family & Parenting', category: 'lifestyle'),
    UserInterest(code: 'lifestyle_religion', emoji: '🕊️', labelFr: 'Religion & Spiritualité', labelEn: 'Religion & Spirituality', category: 'lifestyle'),
    UserInterest(code: 'lifestyle_sante',    emoji: '🧘', labelFr: 'Bien-être & Santé', labelEn: 'Wellness & Health', category: 'lifestyle'),
    UserInterest(code: 'lifestyle_politique', emoji: '🏛️', labelFr: 'Politique & Société', labelEn: 'Politics & Society', category: 'lifestyle'),
    UserInterest(code: 'lifestyle_dating',   emoji: '❤️', labelFr: 'Amour & Rencontres', labelEn: 'Love & Dating', category: 'lifestyle'),
    UserInterest(code: 'lifestyle_automobile', emoji: '🚗', labelFr: 'Automobile & Moto', labelEn: 'Cars & Motorcycles', category: 'lifestyle'),
    UserInterest(code: 'lifestyle_humour',   emoji: '😄', labelFr: 'Humour & Fun', labelEn: 'Humor & Fun', category: 'lifestyle'),

    // ── Gaming & Tech ─────────────────────────────────────────────────────────
    UserInterest(code: 'gaming_mobile',     emoji: '📱', labelFr: 'Gaming Mobile',  labelEn: 'Mobile Gaming',  category: 'gaming'),
    UserInterest(code: 'gaming_console',    emoji: '🎮', labelFr: 'Gaming Console', labelEn: 'Console Gaming', category: 'gaming'),
    UserInterest(code: 'tech_smartphone',   emoji: '📲', labelFr: 'Smartphones & Apps', labelEn: 'Smartphones & Apps', category: 'gaming'),
    UserInterest(code: 'tech_ia',           emoji: '🤖', labelFr: 'Intelligence Artificielle', labelEn: 'Artificial Intelligence', category: 'gaming'),
    UserInterest(code: 'tech_gadgets',      emoji: '🔌', labelFr: 'Gadgets & High-Tech', labelEn: 'Gadgets & High-Tech', category: 'gaming'),
  ];

  // ── Helpers ──────────────────────────────────────────────────────────────────

  static UserInterest? byCode(String code) {
    try {
      return all.firstWhere((i) => i.code == code);
    } catch (_) {
      return null;
    }
  }

  static InterestCategory? categoryById(String id) {
    try {
      return categories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  static bool isCategoryId(String id) => categories.any((c) => c.id == id);

  static List<UserInterest> byCategory(String categoryId) =>
      all.where((i) => i.category == categoryId).toList();

  static bool isValid(String code) => all.any((i) => i.code == code);

  static List<UserInterest> fromCodes(List<String> codes) =>
      codes.map((c) => byCode(c)).whereType<UserInterest>().toList();

  /// Intérêts par défaut pour les nouveaux utilisateurs sans profil configuré.
  /// 1 code populaire par catégorie — utilisés pour le Tier 2 quand interests=[].
  static const List<String> defaults = [
    'music_afrobeat',       // Musique
    'sport_foot',           // Sport
    'dance_afro',           // Danse & Spectacle
    'fashion_mode',         // Mode & Beauté
    'food_cuisine',         // Gastronomie
    'cinema_film',          // Cinéma & Créativité
    'culture_histoire',     // Culture & Savoir
    'business_entrepreneuriat', // Business & Finance
    'lifestyle_voyage',     // Lifestyle & Société
    'gaming_mobile',        // Gaming & Tech
  ];

  // IDs de catégories pour le prompt Gemini
  static String get allCategoryIdsForPrompt =>
      categories.map((c) => '${c.id} (${c.labelFr})').join(', ');

  static Color categoryColor(String categoryId, {bool isDark = false}) {
    switch (categoryId) {
      case 'music':    return isDark ? const Color(0xFFFF6B9D) : const Color(0xFFE91E8C);
      case 'sport':    return isDark ? const Color(0xFF5B9CFA) : const Color(0xFF2979FF);
      case 'dance':    return isDark ? const Color(0xFFFF9500) : const Color(0xFFFF6D00);
      case 'fashion':  return isDark ? const Color(0xFFAF52DE) : const Color(0xFF9C27B0);
      case 'food':     return isDark ? const Color(0xFFFF9248) : const Color(0xFFF57C00);
      case 'cinema':   return isDark ? const Color(0xFF5B9CFA) : const Color(0xFF0D47A1);
      case 'culture':  return isDark ? const Color(0xFF2ECC71) : const Color(0xFF1FAA59);
      case 'business': return isDark ? const Color(0xFFFFE14D) : const Color(0xFFB8860B);
      case 'lifestyle':return isDark ? const Color(0xFF5FCFCF) : const Color(0xFF00897B);
      case 'gaming':   return isDark ? const Color(0xFF9D8AFF) : const Color(0xFF5E35B1);
      default:         return isDark ? const Color(0xFF9A9A95) : const Color(0xFF757575);
    }
  }
}
