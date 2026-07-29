import 'dart:math';

/// Génère 6 suggestions de commentaires variées pour un post.
///
/// Priorité de sélection :
///   1. typeTabbar du post  (SPORT, LOOKS, ACTUALITES, EVENEMENT, OFFRES, GAMER)
///   2. Hashtags extraits de la description
///   3. Mots-clés dans la description
///   4. Emojis détectés dans la description → émotion dominante
///   5. Fallback général shufflé
class CommentSuggestionService {
  static final Random _rng = Random();

  // ─── POOLS PAR TYPE DE POST ──────────────────────────────────────────────────

  static const Map<String, List<String>> _byPostType = {
    'LOOKS': [
      '🔥 Look de folie !', 'Tu assures vraiment 👏', 'Superbe tenue !',
      'Style impeccable ✨', '❤️ Trop beau ce look !', 'Où tu achètes ça ?',
      '😍 Incroyable cette tenue !', 'Tu portes ça trop bien !',
      'Le wax c\'est toujours parfait 🔥', 'Cette couleur te va super bien !',
      'Afrofashion au top 💯', 'Classe et élégant(e) !',
      'Tu es une inspiration style !', '👑 Reine/Roi du look !',
      'J\'adore cette combinaison de couleurs !',
    ],
    'SPORT': [
      '💪 Bravo champion !', 'Super performance !', '🏆 Inarrêtable !',
      'Continue comme ça !', '⚽ Respect !', 'Quelle force !',
      'On est derrière toi ! 💪', 'Le meilleur ! 🔥',
      'Ce match était incroyable !', 'Quelle victoire méritée 🏆',
      'L\'équipe a tout donné !', 'Afrosport au top niveau !',
      '🎯 Précis comme jamais !', 'Ça c\'est du vrai sport !',
      'La relève est là ! 💪', 'Allez allez allez ! 🔥',
    ],
    'ACTUALITES': [
      '🗳️ Très instructif !', 'Important à savoir !', 'Merci pour l\'info 👏',
      'On doit en parler !', '💬 Sujet capital', 'Bon courage à tous !',
      'Merci pour ce partage 🙏', 'Où peut-on en savoir plus ?',
      'C\'est choquant...', 'Le monde change vraiment 😮',
      'Il faut que ça soit vu !', 'Partagez au maximum !',
      'J\'espère que ça s\'arrangera 🙏', 'La vérité doit sortir !',
      'Restez informés 📰', 'L\'Afrique mérite mieux !',
    ],
    'EVENEMENT': [
      '🎉 Ça va être incroyable !', 'Je veux venir !', 'C\'est noté dans l\'agenda !',
      'On se retrouve là-bas 🔥', '🎊 Ça va être chaud !', 'Les billets sont où ?',
      'J\'y serai ! 🙌', 'Tout le monde doit venir !',
      'L\'événement de l\'année 🏆', 'Vivement ce jour !',
      'On va tout déchirer 🔥', 'VIP ou pas, on vient !',
      '🎶 L\'ambiance va être dingue !', 'Préparez-vous !',
      'J\'attends ça avec impatience 🎉', 'Cette soirée sera inoubliable !',
    ],
    'OFFRES': [
      '💼 Super initiative !', 'Courage pour la suite !', 'Je vous soutiens 💪',
      '🚀 Ça va décoller !', 'Beau projet !', 'Continuez comme ça !',
      'C\'est intéressant comme offre !', 'Vous livrez partout ?',
      'Le prix est raisonnable 👍', 'J\'en veux un !',
      'Ça vaut vraiment le coup 💯', 'Commande passée ! 🛒',
      'Qualité irréprochable !', 'Je recommande à 100% 🔥',
      'Service top ! 👌', 'Livraison rapide ? 📦',
    ],
    'GAMER': [
      '🎮 Trop fort !', 'GG WP !', 'Skill level : DIEU 😂',
      'Je veux jouer avec toi !', '🔥 Ça rush dans les lanes !',
      'No cap c\'est fou ce jeu !', 'Ranked ou casual ?',
      'Tu stream ça ?', 'Le gameplay est clean !',
      'J\'aurais pas fait mieux 😂', 'Clutch of the year 🏆',
      'Rage quit imminent 😂', 'PC ou mobile ?',
      'Les ennemis ont rien compris 🤣', 'Headshot only 🎯',
    ],
  };

  // ─── POOLS PAR HASHTAG → THÈME ──────────────────────────────────────────────

  static const Map<String, String> _hashtagToType = {
    'mode': 'LOOKS', 'fashion': 'LOOKS', 'look': 'LOOKS', 'outfit': 'LOOKS',
    'wax': 'LOOKS', 'pagne': 'LOOKS', 'style': 'LOOKS', 'ootd': 'LOOKS',
    'afrofashion': 'LOOKS', 'tenue': 'LOOKS', 'ankara': 'LOOKS',

    'sport': 'SPORT', 'football': 'SPORT', 'basket': 'SPORT', 'soccer': 'SPORT',
    'can2025': 'SPORT', 'match': 'SPORT', 'victoire': 'SPORT', 'goal': 'SPORT',
    'fitness': 'SPORT', 'athletisme': 'SPORT', 'afrosport': 'SPORT',
    'ligue1': 'SPORT', 'training': 'SPORT', 'champion': 'SPORT',

    'actu': 'ACTUALITES', 'news': 'ACTUALITES', 'info': 'ACTUALITES',
    'politique': 'ACTUALITES', 'breaking': 'ACTUALITES', 'debat': 'ACTUALITES',
    'actualite': 'ACTUALITES', 'societe': 'ACTUALITES', 'international': 'ACTUALITES',

    'evenement': 'EVENEMENT', 'concert': 'EVENEMENT', 'festival': 'EVENEMENT',
    'soiree': 'EVENEMENT', 'lancement': 'EVENEMENT', 'fete': 'EVENEMENT',
    'show': 'EVENEMENT', 'spectacle': 'EVENEMENT', 'afterwork': 'EVENEMENT',

    'offre': 'OFFRES', 'promo': 'OFFRES', 'vente': 'OFFRES', 'deal': 'OFFRES',
    'shopping': 'OFFRES', 'reduction': 'OFFRES', 'boutique': 'OFFRES',
    'business': 'OFFRES', 'opportunite': 'OFFRES', 'startup': 'OFFRES',

    'gaming': 'GAMER', 'game': 'GAMER', 'gamer': 'GAMER', 'ps5': 'GAMER',
    'esport': 'GAMER', 'streamer': 'GAMER', 'freefire': 'GAMER',
    'playstation': 'GAMER', 'xbox': 'GAMER', 'pubg': 'GAMER', 'codm': 'GAMER',
  };

  // ─── POOLS PAR THÈME (mots-clés dans description) ───────────────────────────

  static const Map<String, List<String>> _byTheme = {
    'musique': [
      '🎵 Trop bonne musique !', 'Tu as du talent !', "J'adore ce clip 🔥",
      'La suite ?', '🎤 Incroyable !', '❤️ Ce banger est parfait',
      'Cette mélodie reste en tête !', 'En boucle depuis ce matin 🔄',
      'C\'est certifié hit 🏆', 'Le flow est propre !',
      'La prod est immense 🔥', 'Afrobeats toujours au top !',
      'Trop de talent dans cette voix !', 'Le clip est magnifique !',
      'Paroles qui font réfléchir ✨',
    ],
    'cuisine': [
      '😍 Ça a l\'air délicieux !', 'La recette stp !', 'Trop appétissant 🤤',
      'Je veux goûter !', '🍽️ Magnifique !', 'Tu cuisines trop bien !',
      'Mon estomac parle 😂', 'Ça sent bon depuis ici !',
      'Chef étoilé du quartier 👨‍🍳', 'C\'est quoi les ingrédients ?',
      'Ça c\'est de la vraie cuisine africaine 🙌', 'Tu livres ? 😂',
      'Ma grand-mère ferait pareil 🔥', 'Le plat est trop bien présenté !',
      'Invites-moi la prochaine fois 😋',
    ],
    'voyage': [
      '✈️ Chanceux !', 'Quelle belle destination !', "J'adorerais y aller",
      '🌍 Magnifique endroit !', 'On veut venir avec toi 😂', 'Profite bien !',
      'C\'est de toute beauté 😍', 'Le paradis sur Terre !',
      'Les photos sont incroyables !', 'La prochaine fois tu m\'emmènes 🙏',
      'L\'Afrique est sublime 🌍', 'Guide touristique SVP !',
      'Ces paysages... 😮', 'Quelle belle aventure !',
      'Ça fait rêver 🌊',
    ],
    'art': [
      '🎨 Chef d\'œuvre !', 'Tu es très talentueux !', 'Quel talent incroyable 🔥',
      'Continue de créer !', "❤️ J'adore cet art !", 'Sublime travail !',
      'L\'art africain au sommet !', 'Cela devrait être dans un musée !',
      'Le détail est incroyable 😮', 'Tu es un artiste né !',
      'Je veux le prix et le contact 😂', 'Magnifique création !',
      'L\'art n\'a pas de frontière ✨', 'Talent pur !',
      'Continue de nous régaler 🎨',
    ],
    'mariage': [
      '❤️ Félicitations !', 'Que du bonheur à vous deux !', '🎉 Trop happy pour vous !',
      'Votre histoire est belle ❤️', '💍 Merveilleux !', 'Longue vie !',
      'Dieu vous bénisse ❤️', 'Le plus beau jour de vos vies !',
      'Trop émouvant 😭❤️', 'You are goals !',
      'Vive les mariés ! 🎊', 'L\'amour est beau !',
      'Que votre union soit éternelle 🙏', 'Vous êtes magnifiques !',
      'On attend le 1er anniversaire 😂',
    ],
    'bebe': [
      '🍼 Félicitations !', 'Qu\'il/elle est mignon(ne) !', '❤️ Trop beau bébé !',
      'Bienvenue au petit nouveau !', '👶 Tellement adorable !', 'Quelle joie !',
      'Dieu vous a bénis 🙏', 'Ce sourire 😍',
      'Les parents sont trop chanceux ❤️', 'Qu\'il/elle grandisse bien 🙏',
      'Un ange est né 👼', 'On attend le baptême ! 🎉',
      'Ces petits pieds 😍', 'Trop mignon !',
      'La famille s\'agrandit ❤️',
    ],
    'motivation': [
      '💯 Tellement vrai !', 'Merci pour cette sagesse', '🙏 Inspirant !',
      'À partager !', '❤️ Ces mots font du bien', 'Paroles de sage !',
      'Ça m\'a touché(e) directement !', 'Exactement ce dont j\'avais besoin',
      'Sauvegardé pour toujours 💾', 'Continuez à inspirer ! 🔥',
      'La vérité toute nue !', 'Note prise 📝',
      'Que Dieu vous bénisse pour ça 🙏', 'Le monde a besoin de ça !',
      'Partagé à tous mes proches ❤️',
    ],
    'humour': [
      '😂😂😂 J\'en peux plus !', 'Trop drôle !', 'Tu es fait pour la scène !',
      '🤣 Je suis mort(e) !', 'Le meilleur comique ! 😂', 'Encore !',
      'Déclenche mon fou rire à chaque fois 😂', 'Non c\'est trop 🤣',
      'Mon ventre fait mal 😂', 'Génie !',
      'Partage ça à quelqu\'un qui en a besoin 😂', 'J\'ai manqué de mourir de rire 💀',
      'Tu es la définition du LOL 😂', 'J\'attends le prochain 🔥',
      'Ça c\'est du talent comique ! 🎤',
    ],
  };

  // ─── POOLS PAR ÉMOTION (détectée via emojis) ────────────────────────────────

  static const Map<String, List<String>> _byEmotion = {
    'joie': [
      '🎉 Trop content(e) pour toi !', '😍 C\'est magnifique !',
      '🔥 Ça c\'est du bonheur !', '💯 Je suis heureux(se) pour vous !',
      '❤️ Quelle belle nouvelle !', '🙌 On célèbre avec toi !',
      '😊 Ça fait chaud au cœur !', 'Que la joie continue !',
      'Tu mérites tout ça 🌟', 'Béni(e) tu l\'es ! 🙏',
      'C\'est de la pure joie ! 🎊', 'Partage encore du bonheur !',
    ],
    'rires': [
      '😂 Je suis mort(e) !', '🤣 Trop drôle !', 'Arrête tu me fais mourir 😂',
      'Mon fou rire est déclenché 😂', 'Génie absolu !', '💀 J\'en peux plus !',
      'Le comique de l\'année 🏆', 'Trop marrant !',
      'Ma journée est sauvée 😂', 'C\'est trop pour moi 🤣',
      'Partage ça à tous tes contacts 😂', 'Je vais pleurer tellement je ris 😭😂',
    ],
    'tristesse': [
      '😢 Courage à toi', 'Je suis de tout cœur avec toi 🙏',
      '❤️ Je pense à toi', 'Tu n\'es pas seul(e)',
      'Prends soin de toi 🙏', 'Le temps guérit tout, courage ❤️',
      'On est là pour toi 💪', 'Garde la tête haute',
      'Envoie-moi un message si tu veux parler ❤️', 'Force à toi 💪',
      'C\'est dur mais tu vas t\'en sortir 🙏', 'Je prie pour toi ❤️',
    ],
    'condoleances': [
      '🕊️ Que son âme repose en paix', 'Sincères condoléances à toute la famille 🙏',
      '💔 Je partage votre douleur', 'Que Dieu vous donne la force 🙏',
      'Il/Elle restera à jamais dans nos cœurs ❤️', 'Paix à son âme 🕊️',
      'Courage à la famille 🙏', 'Dieu est le plus grand',
      'Que la terre lui soit légère 🙏', 'Triste nouvelle...',
      'Je prie pour le repos de son âme 🕊️', 'Mes prières accompagnent la famille ❤️',
    ],
    'priere': [
      '🙏 Amen !', 'Que Dieu vous bénisse !', '🙏 Je prie pour toi !',
      'Amen amen amen 🙏', 'Que le Seigneur t\'exauce !',
      'Le ciel t\'entend 🙏', 'Bénédiction sur toi ❤️',
      'Je joins ma prière à la tienne 🙏', 'Allah est grand !',
      'Dieu ne déçoit jamais 🙏', 'Ta foi te sauvera ❤️',
      'On prie avec toi 🙏',
    ],
    'colere': [
      '😤 C\'est inacceptable !', 'Je comprends ta colère !', 'Non mais vraiment !',
      'Il faut réagir face à ça 💪', '😡 Pas normal du tout !',
      'On est avec toi ! ✊', 'C\'est scandaleux !',
      'La vérité doit sortir !', 'Ne lâche rien 💪',
      'Justice doit être rendue ! ✊', 'Le combat est juste !',
      'Tu as raison d\'être en colère !',
    ],
    'surprise': [
      '😮 Je n\'en crois pas mes yeux !', 'C\'est dingue !',
      '😱 No way !', 'Quelqu\'un a vu ça ?!',
      'Incroyable vraiment 😮', 'Je l\'aurais jamais cru !',
      'Le monde est fou ! 😱', 'Choqué(e) !',
      'Comment c\'est possible !?', '🤯 Mon cerveau plante là !',
      'Ça m\'a coupé le souffle !', 'C\'est surréaliste !',
    ],
    'amour': [
      '❤️ Tellement beau !', '😍 Je suis amoureux(se) de ce contenu !',
      '🥰 J\'adore ça !', '❤️‍🔥 Love ça !', '💕 Trop touchant !',
      'Ça réchauffe le cœur ❤️', 'L\'amour existe encore 😍',
      'Vous êtes beau/belle ❤️', 'Ce contenu = bonheur pur 🥰',
      'J\'avais besoin de voir ça ❤️', '💖 Adorable !',
      'Tellement d\'amour dans cette publication ❤️',
    ],
    'admiration': [
      '👏 Impressionnant !', 'Tu es une inspiration ! 🌟',
      '🙌 Je t\'admire vraiment !', '💯 Tu es au-delà !',
      'Continue sur cette lancée 🔥', 'Le talent n\'a pas de limite avec toi !',
      'Tu es un exemple ! 🏆', 'Chapeau bas 🎩',
      'Je regarde et j\'apprends !', 'Tu me pousses à faire mieux 💪',
      'Référence absolue 🌟', 'Tu es à un autre niveau !',
    ],
    'nostalgie': [
      '😌 Ça me rappelle de beaux souvenirs...', 'Le bon vieux temps ❤️',
      'C\'était mieux avant 😂', 'Trop de souvenirs 😢❤️',
      'Ces moments me manquent...', 'Ça me revient là 😌',
      'La nostalgie frappe fort 💔', 'Comme le temps passe !',
      'C\'était simple et beau ❤️', 'Je me souviens comme si c\'était hier',
      'Merci pour ce rappel 😌', 'On grandit trop vite 😢',
    ],
  };

  // ─── POOL GÉNÉRAL ────────────────────────────────────────────────────────────

  static const List<String> _general = [
    '🔥 Super post !', "❤️ J'adore", 'Continue comme ça !',
    '👏 Bravo !', '💯 Tellement bien !', '😍 Incroyable !',
    'Merci pour ce partage !', '🙌 Topissime !',
    'Toujours au top !', '🔥 Encore plus svp !',
    'Ça dépote 💪', 'Tu maîtrises !',
    'Post de la journée 🏆', '❤️ C\'est ça qu\'on aime !',
    'On attend la suite !', 'Trop bien ce contenu !',
    '👑 Le/La meilleur(e) !', '💎 Qualité toujours !',
    'Afrolook au max 🔥', 'Partage partage partage !',
    '😊 Ça fait du bien !', 'Vibes au top ✨',
    'Contenu frais comme toujours !', '🎯 Dans le mille !',
    'La crème de la crème 💯', 'En boucle ❤️',
    'Vous avez sauvé ma journée 😂', 'Merci ❤️',
    'Tu te surpasses ! 🌟', 'C\'est du solide !',
  ];

  // ─── MAPPAGE EMOJIS → ÉMOTION ────────────────────────────────────────────────

  static const Map<String, String> _emojiEmotion = {
    '😂': 'rires', '🤣': 'rires', '😹': 'rires',
    '😢': 'tristesse', '😥': 'tristesse', '😰': 'tristesse',
    '😭': 'condoleances',
    '🕊️': 'condoleances', '💔': 'condoleances',
    '🙏': 'priere',
    '😡': 'colere', '😤': 'colere', '🤬': 'colere',
    '😮': 'surprise', '😱': 'surprise', '🤯': 'surprise',
    '❤️': 'amour', '🥰': 'amour', '😍': 'amour', '💕': 'amour',
    '👏': 'admiration', '🏆': 'admiration', '🌟': 'admiration',
    '😌': 'nostalgie',
    '🎉': 'joie', '🎊': 'joie', '😊': 'joie',
  };

  // ─── MAPPAGE MOTS-CLÉS THÈMES ────────────────────────────────────────────────

  static const Map<String, List<String>> _themeKeywords = {
    'musique': ['musique', 'chanson', 'album', 'beat', 'artiste', 'concert', 'chant', 'lyrics', 'clip', 'mixtape', 'freestyle', 'studio', 'playlist', 'afrobeat', 'banger', 'son', 'track'],
    'cuisine': ['recette', 'cuisine', 'plat', 'nourriture', 'repas', 'gateau', 'poulet', 'sauce', 'marmite', 'attieke', 'thieboudienne', 'jollof', 'fufu', 'yassa', 'ndole', 'manger', 'chef'],
    'voyage': ['voyage', 'destination', 'plage', 'safari', 'hotel', 'tourisme', 'vacances', 'paysage', 'decouverte', 'escapade', 'avion', 'valise', 'frontiere'],
    'art': ['dessin', 'peinture', 'photographie', 'illustration', 'oeuvre', 'tableau', 'sculpture', 'calligraphie', 'grafiti', 'portrait', 'aquarelle', 'artiste', 'creatif'],
    'mariage': ['mariage', 'fiancailles', 'fiancé', 'fiancee', 'noces', 'ceremonie', 'bague', 'maries', 'epoux', 'epouse', 'dot', 'demande', 'couple'],
    'bebe': ['bebe', 'naissance', 'grossesse', 'nouveau-ne', 'maternite', 'accouchement', 'nourrisson', 'biberon', 'bapteme', 'enfant', 'nouveau'],
    'motivation': ['motivation', 'inspiration', 'sagesse', 'citation', 'reussite', 'succes', 'mentalite', 'mindset', 'discipline', 'perseverance', 'reve', 'objectif'],
    'humour': ['blague', 'humour', 'drole', 'comedie', 'rire', 'sketch', 'meme', 'gag', 'marrant', 'comique', 'lol'],
  };

  // ─── API PUBLIQUE ────────────────────────────────────────────────────────────

  /// Retourne 6 suggestions variées. Shufflées à chaque appel — jamais les mêmes.
  static List<String> getSuggestions(
    String postId,
    String description, {
    String? postType,
    List<String>? hashtags,
  }) {
    final pool = _selectPool(description, postType: postType, hashtags: hashtags);
    final shuffled = List<String>.from(pool)..shuffle(_rng);
    final result = shuffled.take(6).toList();

    // Compléter avec le général si moins de 6
    if (result.length < 6) {
      final extra = List<String>.from(_general)..shuffle(_rng);
      for (final s in extra) {
        if (!result.contains(s)) result.add(s);
        if (result.length >= 6) break;
      }
    }
    return result.take(6).toList();
  }

  // ─── SÉLECTION DU POOL ───────────────────────────────────────────────────────

  static List<String> _selectPool(
    String description, {
    String? postType,
    List<String>? hashtags,
  }) {
    // 1. Type de post explicite (SPORT, LOOKS, ACTUALITES, EVENEMENT, OFFRES, GAMER)
    if (postType != null && _byPostType.containsKey(postType)) {
      return _byPostType[postType]!;
    }

    // 2. Hashtags dans la description
    final extractedTags = _extractHashtags(description);
    final allTags = {...extractedTags, ...(hashtags ?? [])};
    for (final tag in allTags) {
      final clean = _normalize(tag.replaceAll('#', ''));
      if (_hashtagToType.containsKey(clean)) {
        final type = _hashtagToType[clean]!;
        return _byPostType[type]!;
      }
    }

    // 3. Mots-clés thématiques dans la description
    final lower = _normalize(description);
    for (final entry in _themeKeywords.entries) {
      for (final kw in entry.value) {
        if (RegExp(r'\b' + RegExp.escape(kw) + r'\b').hasMatch(lower)) {
          if (_byTheme.containsKey(entry.key)) return _byTheme[entry.key]!;
        }
      }
    }

    // 4. Émotion dominante via emojis
    final emotion = _detectEmotion(description);
    if (emotion != null && _byEmotion.containsKey(emotion)) {
      return _byEmotion[emotion]!;
    }

    // 5. Fallback général
    return _general;
  }

  // ─── HELPERS ─────────────────────────────────────────────────────────────────

  static List<String> _extractHashtags(String text) {
    final matches = RegExp(r'#\w+').allMatches(text);
    return matches.map((m) => m.group(0)!.toLowerCase()).toList();
  }

  static String? _detectEmotion(String text) {
    final counts = <String, int>{};
    for (final entry in _emojiEmotion.entries) {
      if (text.contains(entry.key)) {
        counts[entry.value] = (counts[entry.value] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return null;
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  static String _normalize(String input) {
    const with_ = 'àáâãäåçèéêëìíîïñòóôõöùúûüý';
    const with__ = 'aaaaaaceeeeiiiinooooouuuuy';
    final buf = StringBuffer();
    for (final rune in input.runes) {
      final c = String.fromCharCode(rune);
      final idx = with_.indexOf(c);
      buf.write(idx >= 0 ? with__[idx] : c);
    }
    return buf.toString();
  }
}
