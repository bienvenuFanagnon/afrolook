import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_smart_reply/google_mlkit_smart_reply.dart';

/// Génère des suggestions de commentaires pour un post.
/// Tier 2 : ML Kit Smart Reply (on-device, ~100ms, 0 MB extra)
/// Tier 3 : templates par thème (fallback universel, <1ms)
class CommentSuggestionService {
  static final Map<String, List<String>> _cache = {};
  static const int _maxCacheSize = 50;

  // Chaque thème : liste de mots-clés exacts (correspondance mot entier uniquement)
  static const List<_Theme> _themes = [
    _Theme(
      keywords: ['musique', 'chanson', 'album', 'beat', 'artiste', 'concert', 'chant', 'lyrics', 'clip', 'mixtape', 'instrumental', 'freestyle', 'studio', 'playlist', 'afrobeat'],
      suggestions: [
        '🎵 Trop bonne musique !', 'Tu as du talent !', "J'adore ce clip 🔥",
        'La suite ?', '🎤 Incroyable !', '❤️ Ce banger est parfait',
      ],
    ),
    _Theme(
      keywords: ['mode', 'vetement', 'tenue', 'look', 'fashion', 'robe', 'veste', 'chemise', 'pagne', 'tissu', 'styliste', 'collection', 'outfit', 'wax'],
      suggestions: [
        '🔥 Look de folie !', 'Tu assures vraiment 👏', 'Superbe tenue !',
        'Où tu achètes ça ?', 'Style impeccable ✨', '❤️ Trop beau ce look !',
      ],
    ),
    _Theme(
      keywords: ['recette', 'cuisine', 'plat', 'nourriture', 'repas', 'gateau', 'poulet', 'sauce', 'marmite', 'attiéké', 'thieboudienne', 'jollof', 'fufu', 'yassa', 'ndole'],
      suggestions: [
        '😍 Ça a l\'air délicieux !', 'La recette stp !', 'Trop appétissant 🤤',
        'Je veux goûter !', '🍽️ Magnifique !', 'Tu cuisines trop bien !',
      ],
    ),
    _Theme(
      keywords: ['football', 'basket', 'tennis', 'judo', 'athletisme', 'match', 'victoire', 'equipe', 'goal', 'champion', 'tournoi', 'stade', 'ballon', 'entrainement'],
      suggestions: [
        '💪 Bravo champion !', 'Super performance !', '🏆 Inarrêtable !',
        'Continue comme ça !', '⚽ Respect !', 'Quelle force !',
      ],
    ),
    _Theme(
      keywords: ['voyage', 'destination', 'plage', 'safari', 'hotel', 'tourisme', 'vacances', 'paysage', 'vols', 'frontiere', 'passeport', 'valise', 'decouverte'],
      suggestions: [
        '✈️ Chanceux !', 'Quelle belle destination !', "J'adorerais y aller",
        '🌍 Magnifique endroit !', 'On veut venir avec toi 😂', 'Profite bien !',
      ],
    ),
    _Theme(
      keywords: ['dessin', 'peinture', 'photographie', 'illustration', 'oeuvre', 'tableau', 'sculpture', 'calligraphie', 'grafiti', 'portrait', 'aquarelle'],
      suggestions: [
        '🎨 Chef d\'œuvre !', 'Tu es très talentueux !', 'Quel talent incroyable 🔥',
        'Continue de créer !', "❤️ J'adore cet art !", 'Sublime travail !',
      ],
    ),
    _Theme(
      keywords: ['mariage', 'fiancailles', 'fiancé', 'fiancée', 'noces', 'ceremonie', 'bague', 'mariés', 'epoux', 'epouse', 'dot'],
      suggestions: [
        '❤️ Félicitations !', 'Que du bonheur à vous deux !', '🎉 Trop happy pour vous !',
        'Votre histoire est belle ❤️', '💍 Merveilleux !', 'Longue vie !',
      ],
    ),
    _Theme(
      keywords: ['bebe', 'naissance', 'grossesse', 'nouveau-né', 'maternite', 'accouchement', 'nourrisson', 'biberon', 'bapteme'],
      suggestions: [
        '🍼 Félicitations !', 'Qu\'il est mignon !', '❤️ Trop beau bébé !',
        'Bienvenue au petit nouveau !', '👶 Tellement adorable !', 'Quelle joie !',
      ],
    ),
    _Theme(
      keywords: ['politique', 'gouvernement', 'election', 'president', 'ministre', 'parlement', 'loi', 'democratie', 'citoyens', 'nation', 'republique', 'pouvoir', 'opposition', 'vote'],
      suggestions: [
        '🗳️ Très instructif !', 'Important à savoir !', 'Merci pour l\'info 👏',
        'On doit en parler !', '💬 Sujet capital', 'Bon courage à tous !',
      ],
    ),
    _Theme(
      keywords: ['startup', 'entreprise', 'business', 'vente', 'commerce', 'investissement', 'financement', 'projet', 'entrepreneur', 'opportunite', 'marche', 'client'],
      suggestions: [
        '💼 Super initiative !', 'Courage pour la suite !', 'Je vous soutiens 💪',
        '🚀 Ça va décoller !', 'Beau projet !', 'Continuez comme ça !',
      ],
    ),
    _Theme(
      keywords: ['motivation', 'inspiration', 'sagesse', 'citation', 'pensee', 'reussite', 'succes', 'mentalite', 'mindset', 'discipline', 'perseverance'],
      suggestions: [
        '💯 Tellement vrai !', 'Merci pour cette sagesse', '🙏 Inspirant !',
        'À partager !', '❤️ Ces mots font du bien', 'Paroles de sage !',
      ],
    ),
  ];

  static const List<String> _defaultSuggestions = [
    '🔥 Super post !',
    "❤️ J'adore",
    'Continue comme ça !',
    '👏 Bravo !',
    '💯 Tellement bien !',
    '😍 Incroyable !',
  ];

  /// Retourne 6 suggestions pour ce post. Utilise le cache si disponible.
  /// À appeler en `async` depuis initState — ML Kit est non-bloquant en interne.
  static Future<List<String>> getSuggestions(
    String postId,
    String description,
  ) async {
    if (_cache.containsKey(postId)) return _cache[postId]!;

    List<String> mlKitSuggestions = [];

    // Tier 2 : ML Kit Smart Reply (Android/iOS seulement)
    if (!kIsWeb && description.trim().isNotEmpty) {
      try {
        final smartReply = SmartReply();
        // Simuler une conversation : le post est le message reçu
        final text =
            description.length > 400 ? description.substring(0, 400) : description;
        smartReply.addMessageToConversationFromRemoteUser(
          text,
          DateTime.now().millisecondsSinceEpoch - 2000,
          'post_author',
        );
        final result = await smartReply.suggestReplies();
        await smartReply.close();

        if (result.status == SmartReplySuggestionResultStatus.success) {
          mlKitSuggestions = List<String>.from(result.suggestions);
        }
      } catch (_) {
        // Fallback silencieux vers Tier 3
      }
    }

    // Tier 3 : compléter jusqu'à 6 avec templates thématiques
    final themePool = _getThemeTemplates(description);
    final needed = 6 - mlKitSuggestions.length;
    if (needed > 0) {
      final shuffled = List.of(themePool)..shuffle(Random());
      mlKitSuggestions.addAll(shuffled.take(needed));
    }

    final result = mlKitSuggestions.take(6).toList();
    _addToCache(postId, result);
    return result;
  }

  static void _addToCache(String key, List<String> value) {
    if (_cache.length >= _maxCacheSize) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = value;
  }

  /// Invalide le cache d'un post (après envoi d'un commentaire par ex.)
  static void invalidate(String postId) => _cache.remove(postId);

  static List<String> _getThemeTemplates(String description) {
    final lower = _removeDiacritics(description.toLowerCase());
    for (final theme in _themes) {
      for (final kw in theme.keywords) {
        // Correspondance mot entier uniquement (évite "son" dans "gouvernement")
        if (RegExp(r'\b' + RegExp.escape(kw) + r'\b').hasMatch(lower)) {
          return theme.suggestions;
        }
      }
    }
    return _defaultSuggestions;
  }

  // Supprime les accents pour que "réussite" matche "reussite" etc.
  static String _removeDiacritics(String input) {
    const withDiacritics    = 'àáâãäåæçèéêëìíîïðñòóôõöùúûüýÿœ';
    const withoutDiacritics = 'aaaaaæceeeeiiiidnoooooouuuuyyoe';
    final buffer = StringBuffer();
    for (final char in input.runes) {
      final c = String.fromCharCode(char);
      final idx = withDiacritics.indexOf(c);
      buffer.write(idx >= 0 ? withoutDiacritics[idx] : c);
    }
    return buffer.toString();
  }
}

class _Theme {
  final List<String> keywords;
  final List<String> suggestions;
  const _Theme({required this.keywords, required this.suggestions});
}

