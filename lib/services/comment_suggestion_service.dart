import 'dart:math';

/// Génère 6 suggestions de commentaires intelligentes pour un post.
///
/// Système multi-signaux pondérés :
///   Hashtags (avec stemming + fuzzy)  → poids 3
///   Expressions multi-mots            → poids variable (2-5)
///   Mots-clés description (cumulatif) → poids 2 par match, max 4
///   Emojis (comptés)                  → poids 2 par emoji, max 4
///   postType                          → poids 1 (tiebreaker uniquement)
///
/// Le thème gagnant détermine le pool. Si 2 thèmes sont proches (≥70%),
/// leurs pools sont fusionnés pour plus de variété.
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

  // ─── POOLS PAR THÈME ────────────────────────────────────────────────────────

  static const Map<String, List<String>> _byTheme = {
    'humour': [
      '😂😂😂 J\'en peux plus !', 'Trop drôle !', 'Tu es fait pour la scène !',
      '🤣 Je suis mort(e) !', 'Le meilleur comique ! 😂', 'Encore !',
      'Déclenche mon fou rire à chaque fois 😂', 'Non c\'est trop 🤣',
      'Mon ventre fait mal 😂', 'Génie absolu !',
      'Tu vas me tuer avec tes blagues 💀', 'J\'ai manqué de mourir de rire 💀',
      'Tu es la définition du LOL 😂', 'J\'attends le prochain 🔥',
      'Ça c\'est du talent comique ! 🎤', 'Cette blague 😂💀',
      'Tu m\'as tué ! 🤣', 'Partage ça à quelqu\'un qui en a besoin 😂',
    ],
    'musique': [
      '🎵 Trop bonne musique !', 'Tu as du talent !', "J'adore ce clip 🔥",
      'La suite ?', '🎤 Incroyable !', '❤️ Ce banger est parfait',
      'Cette mélodie reste en tête !', 'En boucle depuis ce matin 🔄',
      'C\'est certifié hit 🏆', 'Le flow est propre !',
      'La prod est immense 🔥', 'Afrobeats toujours au top !',
      'Trop de talent dans cette voix !', 'Le clip est magnifique !',
      'Paroles qui font réfléchir ✨', 'Quelle puissance vocale ! 🎶',
      'C\'est en boucle depuis hier 🔁', 'Le prochain album ?',
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
  };

  // ─── POOLS PAR ÉMOTION ───────────────────────────────────────────────────────

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

  // ─── HASHTAG → THÈME UNIVERSEL ──────────────────────────────────────────────
  // Couvre tous les thèmes et émotions (formes singulières — le stemming gère les pluriels)

  static const Map<String, String> _hashtagToTheme = {
    // ── Humour / Rires ──
    'blague': 'humour', 'humour': 'humour', 'drole': 'humour', 'lol': 'humour',
    'mdr': 'humour', 'marrant': 'humour', 'comedie': 'humour', 'sketch': 'humour',
    'rigolo': 'humour', 'haha': 'humour', 'funny': 'humour', 'xptdr': 'humour',
    'gag': 'humour', 'joke': 'humour', 'comique': 'humour', 'ptdr': 'humour',
    'prank': 'humour', 'troll': 'humour', 'meme': 'humour', 'rire': 'humour',
    'mort': 'humour', 'lmao': 'humour', 'rofl': 'humour',

    // ── Musique ──
    'musique': 'musique', 'chanson': 'musique', 'artiste': 'musique',
    'afrobeat': 'musique', 'rap': 'musique', 'clip': 'musique',
    'banger': 'musique', 'track': 'musique', 'album': 'musique',
    'mixtape': 'musique', 'playlist': 'musique', 'studio': 'musique',
    'freestyle': 'musique', 'beat': 'musique', 'chanteur': 'musique',
    'chanteuse': 'musique', 'singer': 'musique', 'afropop': 'musique',
    'coupedecale': 'musique', 'ndombolo': 'musique', 'zouglou': 'musique',
    'highlife': 'musique', 'lyric': 'musique', 'rnb': 'musique',
    'hiphop': 'musique', 'dancehall': 'musique', 'amapiano': 'musique',
    'afrosoul': 'musique', 'son': 'musique', 'melodie': 'musique',
    'instrumental': 'musique', 'concert': 'musique',

    // ── Fashion / Look ──
    'look': 'LOOKS', 'mode': 'LOOKS', 'fashion': 'LOOKS', 'outfit': 'LOOKS',
    'style': 'LOOKS', 'wax': 'LOOKS', 'pagne': 'LOOKS', 'ootd': 'LOOKS',
    'afrofashion': 'LOOKS', 'tenue': 'LOOKS', 'ankara': 'LOOKS',
    'collection': 'LOOKS', 'dressing': 'LOOKS', 'swag': 'LOOKS',
    'tendance': 'LOOKS', 'couture': 'LOOKS', 'kente': 'LOOKS',
    'dashiki': 'LOOKS', 'boubou': 'LOOKS', 'accessoire': 'LOOKS',
    'bijou': 'LOOKS', 'vetement': 'LOOKS', 'modele': 'LOOKS',

    // ── Sport ──
    'sport': 'SPORT', 'football': 'SPORT', 'basket': 'SPORT', 'soccer': 'SPORT',
    'can2025': 'SPORT', 'match': 'SPORT', 'victoire': 'SPORT', 'goal': 'SPORT',
    'fitness': 'SPORT', 'athletisme': 'SPORT', 'afrosport': 'SPORT',
    'ligue1': 'SPORT', 'training': 'SPORT', 'champion': 'SPORT',
    'handball': 'SPORT', 'rugby': 'SPORT', 'natation': 'SPORT',
    'tennis': 'SPORT', 'boxe': 'SPORT', 'gym': 'SPORT',
    'musculation': 'SPORT', 'running': 'SPORT', 'marathon': 'SPORT',
    'buteur': 'SPORT', 'penalty': 'SPORT', 'ballon': 'SPORT',
    'equipe': 'SPORT', 'stade': 'SPORT', 'competition': 'SPORT',

    // ── Actualités ──
    'actu': 'ACTUALITES', 'news': 'ACTUALITES', 'info': 'ACTUALITES',
    'politique': 'ACTUALITES', 'breaking': 'ACTUALITES', 'debat': 'ACTUALITES',
    'actualite': 'ACTUALITES', 'societe': 'ACTUALITES', 'international': 'ACTUALITES',
    'gouvernement': 'ACTUALITES', 'election': 'ACTUALITES', 'economie': 'ACTUALITES',
    'afrique': 'ACTUALITES', 'monde': 'ACTUALITES', 'journalisme': 'ACTUALITES',
    'alerte': 'ACTUALITES', 'reportage': 'ACTUALITES', 'exclusif': 'ACTUALITES',

    // ── Événement ──
    'evenement': 'EVENEMENT', 'festival': 'EVENEMENT', 'soiree': 'EVENEMENT',
    'lancement': 'EVENEMENT', 'fete': 'EVENEMENT', 'show': 'EVENEMENT',
    'spectacle': 'EVENEMENT', 'afterwork': 'EVENEMENT', 'gala': 'EVENEMENT',
    'conference': 'EVENEMENT', 'ceremonie': 'EVENEMENT', 'party': 'EVENEMENT',
    'carnaval': 'EVENEMENT', 'inauguration': 'EVENEMENT',

    // ── Offres / Business ──
    'offre': 'OFFRES', 'promo': 'OFFRES', 'vente': 'OFFRES', 'deal': 'OFFRES',
    'shopping': 'OFFRES', 'reduction': 'OFFRES', 'boutique': 'OFFRES',
    'business': 'OFFRES', 'opportunite': 'OFFRES', 'startup': 'OFFRES',
    'entrepreneur': 'OFFRES', 'ecommerce': 'OFFRES', 'livraison': 'OFFRES',
    'produit': 'OFFRES', 'solde': 'OFFRES', 'nouveaute': 'OFFRES',

    // ── Gaming ──
    'gaming': 'GAMER', 'game': 'GAMER', 'gamer': 'GAMER', 'ps5': 'GAMER',
    'esport': 'GAMER', 'streamer': 'GAMER', 'freefire': 'GAMER',
    'playstation': 'GAMER', 'xbox': 'GAMER', 'pubg': 'GAMER', 'codm': 'GAMER',
    'twitch': 'GAMER', 'minecraft': 'GAMER', 'fortnite': 'GAMER',
    'ranked': 'GAMER', 'clutch': 'GAMER', 'mobile': 'GAMER',

    // ── Cuisine / Food ──
    'cuisine': 'cuisine', 'recette': 'cuisine', 'food': 'cuisine',
    'foodie': 'cuisine', 'chef': 'cuisine', 'plat': 'cuisine',
    'repas': 'cuisine', 'gateau': 'cuisine', 'poulet': 'cuisine',
    'attieke': 'cuisine', 'jollof': 'cuisine', 'fufu': 'cuisine',
    'yassa': 'cuisine', 'ndole': 'cuisine', 'mafe': 'cuisine',
    'thieboudienne': 'cuisine', 'alloco': 'cuisine', 'streetfood': 'cuisine',
    'restaurant': 'cuisine', 'sauce': 'cuisine', 'delicieux': 'cuisine',

    // ── Voyage / Travel ──
    'voyage': 'voyage', 'travel': 'voyage', 'plage': 'voyage',
    'safari': 'voyage', 'hotel': 'voyage', 'tourisme': 'voyage',
    'vacance': 'voyage', 'paysage': 'voyage', 'decouverte': 'voyage',
    'escapade': 'voyage', 'aventure': 'voyage', 'roadtrip': 'voyage',
    'destination': 'voyage', 'expatrie': 'voyage', 'backpacker': 'voyage',

    // ── Art / Créativité ──
    'art': 'art', 'dessin': 'art', 'peinture': 'art',
    'photographie': 'art', 'photo': 'art', 'illustration': 'art',
    'oeuvre': 'art', 'tableau': 'art', 'sculpture': 'art',
    'graffiti': 'art', 'portrait': 'art', 'aquarelle': 'art',
    'creative': 'art', 'photographe': 'art', 'aesthetic': 'art',
    'design': 'art', 'graphisme': 'art',

    // ── Mariage ──
    'mariage': 'mariage', 'fiancaille': 'mariage', 'noce': 'mariage',
    'bague': 'mariage', 'dot': 'mariage', 'wedding': 'mariage',
    'propose': 'mariage', 'lune_de_miel': 'mariage',

    // ── Amour / Couple ──
    'couple': 'amour', 'love': 'amour', 'amour': 'amour',
    'romance': 'amour', 'valentin': 'amour', 'crush': 'amour',
    'relationshipgoal': 'amour',

    // ── Bébé / Famille ──
    'bebe': 'bebe', 'naissance': 'bebe', 'grossesse': 'bebe',
    'maternite': 'bebe', 'accouchement': 'bebe', 'bapteme': 'bebe',
    'famille': 'bebe', 'enfant': 'bebe', 'maman': 'bebe', 'papa': 'bebe',
    'newborn': 'bebe', 'enceinte': 'bebe',

    // ── Motivation / Inspiration ──
    'motivation': 'motivation', 'inspiration': 'motivation', 'sagesse': 'motivation',
    'citation': 'motivation', 'reussite': 'motivation', 'succes': 'motivation',
    'mindset': 'motivation', 'discipline': 'motivation', 'objectif': 'motivation',
    'perseverance': 'motivation', 'reve': 'motivation', 'quote': 'motivation',
    'growth': 'motivation', 'positif': 'motivation',

    // ── Tristesse ──
    'triste': 'tristesse', 'tristesse': 'tristesse', 'depression': 'tristesse',
    'seul': 'tristesse', 'solitude': 'tristesse', 'douleur': 'tristesse',
    'peine': 'tristesse', 'cafard': 'tristesse',

    // ── Condoléances ──
    'rip': 'condoleances', 'dece': 'condoleances', 'condoleance': 'condoleances',
    'perte': 'condoleances', 'deuil': 'condoleances', 'disparu': 'condoleances',
    'hommage': 'condoleances', 'reposenpaixe': 'condoleances',

    // ── Prière / Spiritualité ──
    'priere': 'priere', 'amen': 'priere', 'dieu': 'priere',
    'allah': 'priere', 'foi': 'priere', 'benediction': 'priere',
    'eglise': 'priere', 'mosquee': 'priere', 'grace': 'priere',
    'spirituel': 'priere', 'prophetie': 'priere', 'delivrance': 'priere',
    'pasteur': 'priere', 'imam': 'priere', 'gospel': 'priere',

    // ── Colère / Indignation ──
    'injustice': 'colere', 'scandale': 'colere', 'corruption': 'colere',
    'impunite': 'colere', 'racisme': 'colere', 'discrimination': 'colere',
    'revolte': 'colere', 'inacceptable': 'colere',

    // ── Surprise ──
    'wtf': 'surprise', 'incroyable': 'surprise', 'choc': 'surprise',
    'waou': 'surprise', 'omg': 'surprise', 'incredule': 'surprise',
    'impossible': 'surprise', 'surreal': 'surprise',

    // ── Admiration ──
    'talent': 'admiration', 'genius': 'admiration', 'goat': 'admiration',
    'legend': 'admiration', 'respect': 'admiration', 'fier': 'admiration',
    'fierte': 'admiration', 'bravo': 'admiration', 'icon': 'admiration',

    // ── Nostalgie ──
    'nostalgie': 'nostalgie', 'souvenir': 'nostalgie', 'memoire': 'nostalgie',
    'throwback': 'nostalgie', 'retro': 'nostalgie', 'vintage': 'nostalgie',
    'tbt': 'nostalgie', 'flashback': 'nostalgie',
  };

  // ─── EXPRESSIONS MULTI-MOTS ──────────────────────────────────────────────────
  // (pattern_normalisé, thème, poids) — analysées dans la description complète

  static const List<(String, String, int)> _multiWordPatterns = [
    // Humour
    ('je suis mort', 'humour', 5),
    ('mort de rire', 'humour', 5),
    ('je pleure de rire', 'humour', 5),
    ('trop drole', 'humour', 4),
    ('trop marrant', 'humour', 4),
    ('je ris', 'humour', 3),
    ('fait rire', 'humour', 3),
    ('bonne blague', 'humour', 4),
    // Condoléances
    ('repose en paix', 'condoleances', 5),
    ('rest in peace', 'condoleances', 5),
    ('sinceres condoleances', 'condoleances', 5),
    ('nous a quittes', 'condoleances', 4),
    ('nous a quitte', 'condoleances', 4),
    // Prière
    ('que dieu', 'priere', 3),
    ('que allah', 'priere', 3),
    ('je prie pour', 'priere', 4),
    ('au nom de dieu', 'priere', 4),
    // Cuisine
    ('recette de', 'cuisine', 4),
    ('comment preparer', 'cuisine', 4),
    ('les ingredients', 'cuisine', 4),
    ('ca sent bon', 'cuisine', 3),
    // Sport
    ('on a gagne', 'SPORT', 4),
    ('victoire de', 'SPORT', 4),
    ('beau but', 'SPORT', 4),
    ('prochain match', 'SPORT', 3),
    // Musique
    ('nouveau clip', 'musique', 4),
    ('nouvel album', 'musique', 4),
    ('nouvelle chanson', 'musique', 4),
    ('en boucle', 'musique', 3),
    // Mariage
    ('elle a dit oui', 'mariage', 5),
    ('il a dit oui', 'mariage', 5),
    ('fiancee avec', 'mariage', 4),
    ('fiance avec', 'mariage', 4),
    // Bébé
    ('bonne nouvelle', 'joie', 3),
    ('je suis enceinte', 'bebe', 5),
    ('elle est enceinte', 'bebe', 5),
    ('accouche de', 'bebe', 5),
    // Mode
    ('nouvelle tenue', 'LOOKS', 4),
    ('nouvelle collection', 'LOOKS', 4),
    // Actualités
    ('breaking news', 'ACTUALITES', 4),
    ('en direct de', 'ACTUALITES', 3),
    // Joie
    ('trop content', 'joie', 3),
    ('trop heureuse', 'joie', 3),
    ('trop heureux', 'joie', 3),
    // Nostalgie
    ('bon vieux temps', 'nostalgie', 4),
    ('ca me rappelle', 'nostalgie', 3),
    ('les souvenirs', 'nostalgie', 3),
    // Tristesse
    ('je souffre', 'tristesse', 3),
    ('c est dur', 'tristesse', 2),
    ('ca fait mal', 'tristesse', 3),
  ];

  // ─── MOTS-CLÉS PAR THÈME ─────────────────────────────────────────────────────

  static const Map<String, List<String>> _themeKeywords = {
    'humour': [
      'blague', 'humour', 'drole', 'comedie', 'rire', 'sketch', 'meme', 'gag',
      'marrant', 'comique', 'lol', 'mdr', 'ptdr', 'xptdr', 'rigolo', 'funny',
      'prank', 'trop fort', 'je suis mort', 'mort de rire',
    ],
    'musique': [
      'musique', 'chanson', 'album', 'beat', 'artiste', 'chant', 'lyrics',
      'clip', 'mixtape', 'freestyle', 'studio', 'playlist', 'afrobeat', 'banger',
      'son', 'track', 'melodie', 'couplet', 'refrain', 'instrumental',
    ],
    'cuisine': [
      'recette', 'cuisine', 'plat', 'nourriture', 'repas', 'gateau', 'poulet',
      'sauce', 'marmite', 'attieke', 'thieboudienne', 'jollof', 'fufu', 'yassa',
      'ndole', 'manger', 'chef', 'ingredient', 'delicieux', 'appétissant',
    ],
    'voyage': [
      'voyage', 'destination', 'plage', 'safari', 'hotel', 'tourisme',
      'vacances', 'paysage', 'decouverte', 'escapade', 'avion', 'valise',
      'frontiere', 'expatrie', 'aventure',
    ],
    'art': [
      'dessin', 'peinture', 'photographie', 'illustration', 'oeuvre', 'tableau',
      'sculpture', 'calligraphie', 'grafiti', 'portrait', 'aquarelle', 'artiste',
      'creatif', 'aesthetic', 'design',
    ],
    'mariage': [
      'mariage', 'fiancailles', 'fiance', 'fiancee', 'noces', 'ceremonie',
      'bague', 'maries', 'epoux', 'epouse', 'dot', 'demande', 'couple',
    ],
    'bebe': [
      'bebe', 'naissance', 'grossesse', 'nouveau-ne', 'maternite', 'accouchement',
      'nourrisson', 'biberon', 'bapteme', 'enfant', 'enceinte', 'nouveau',
    ],
    'motivation': [
      'motivation', 'inspiration', 'sagesse', 'citation', 'reussite', 'succes',
      'mentalite', 'mindset', 'discipline', 'perseverance', 'reve', 'objectif',
    ],
  };

  // ─── EMOJIS → ÉMOTION ────────────────────────────────────────────────────────

  static const Map<String, String> _emojiToEmotion = {
    '😂': 'humour', '🤣': 'humour', '😹': 'humour', '💀': 'humour',
    '😢': 'tristesse', '😥': 'tristesse', '😰': 'tristesse',
    '😭': 'condoleances',
    '🕊️': 'condoleances', '💔': 'condoleances',
    '🙏': 'priere',
    '😡': 'colere', '😤': 'colere', '🤬': 'colere',
    '😮': 'surprise', '😱': 'surprise', '🤯': 'surprise',
    '❤️': 'amour', '🥰': 'amour', '😍': 'amour', '💕': 'amour', '❤️‍🔥': 'amour',
    '👏': 'admiration', '🏆': 'admiration', '🌟': 'admiration', '🙌': 'admiration',
    '😌': 'nostalgie',
    '🎉': 'joie', '🎊': 'joie', '😊': 'joie', '🥳': 'joie',
    '🎵': 'musique', '🎤': 'musique', '🎶': 'musique',
    '⚽': 'SPORT', '🏀': 'SPORT', '💪': 'SPORT',
    '✈️': 'voyage', '🌍': 'voyage', '🏖️': 'voyage',
    '🍽️': 'cuisine', '😋': 'cuisine', '🤤': 'cuisine',
    '🎨': 'art', '🖌️': 'art',
    '💍': 'mariage', '👰': 'mariage',
    '👶': 'bebe', '🍼': 'bebe',
    '🎮': 'GAMER', '🕹️': 'GAMER',
  };

  // ─── API PUBLIQUE ────────────────────────────────────────────────────────────

  /// Retourne 6 suggestions intelligentes. Différentes à chaque appel.
  static List<String> getSuggestions(
    String postId,
    String description, {
    String? postType,
    List<String>? hashtags,
  }) {
    final pool = _selectPool(description, postType: postType, hashtags: hashtags);
    final shuffled = List<String>.from(pool)..shuffle(_rng);
    final result = shuffled.take(6).toList();

    if (result.length < 6) {
      final extra = List<String>.from(_general)..shuffle(_rng);
      for (final s in extra) {
        if (!result.contains(s)) result.add(s);
        if (result.length >= 6) break;
      }
    }
    return result.take(6).toList();
  }

  // ─── SÉLECTION PAR SCORE MULTI-SIGNAUX ──────────────────────────────────────

  static List<String> _selectPool(
    String description, {
    String? postType,
    List<String>? hashtags,
  }) {
    final scores = <String, int>{};
    final hasHashtags = description.contains('#') || (hashtags?.isNotEmpty ?? false);
    final descNorm = _normalize(description.toLowerCase());

    // ── Signal 1 : Hashtags avec stemming + fuzzy (poids 3) ──────────────────
    final extractedTags = _extractHashtags(description);
    final allTags = {...extractedTags, ...(hashtags ?? [])};
    for (final tag in allTags) {
      final clean = _normalize(tag.replaceAll('#', ''));
      final theme = _lookupHashtag(clean);
      if (theme != null) {
        scores[theme] = (scores[theme] ?? 0) + 3;
      }
    }

    // ── Signal 2 : Expressions multi-mots (poids variable 2-5) ───────────────
    for (final (pattern, theme, weight) in _multiWordPatterns) {
      if (descNorm.contains(pattern)) {
        scores[theme] = (scores[theme] ?? 0) + weight;
      }
    }

    // ── Signal 3 : Mots-clés description (poids cumulatif, max 4) ────────────
    for (final entry in _themeKeywords.entries) {
      int matchCount = 0;
      for (final kw in entry.value) {
        if (descNorm.contains(kw)) matchCount++;
      }
      if (matchCount > 0) {
        // 1 match = +2, 2+ matches = +4 (signal renforcé)
        scores[entry.key] = (scores[entry.key] ?? 0) + (matchCount > 1 ? 4 : 2);
      }
    }

    // ── Signal 4 : Emojis (comptés, poids 2 par type, max +4) ────────────────
    final emojiCounts = <String, int>{};
    for (final entry in _emojiToEmotion.entries) {
      if (description.contains(entry.key)) {
        emojiCounts[entry.value] = (emojiCounts[entry.value] ?? 0) + 1;
      }
    }
    for (final entry in emojiCounts.entries) {
      // Plusieurs emojis du même type renforcent le signal
      scores[entry.key] = (scores[entry.key] ?? 0) + (entry.value > 1 ? 4 : 2);
    }

    // ── Signal 5 : postType (poids 1 — tiebreaker uniquement) ────────────────
    if (postType != null && postType.isNotEmpty) {
      scores[postType] = (scores[postType] ?? 0) + 1;
    }

    // ── Aucun signal reconnu ──────────────────────────────────────────────────
    if (scores.isEmpty) {
      return hasHashtags ? _general : _buildEmotionMixedPool();
    }

    // ── Classement et fusion si 2 thèmes proches (≥70% du score gagnant) ─────
    final sorted = scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final winner = sorted.first.key;
    final topScore = sorted.first.value;

    if (sorted.length > 1 && sorted[1].value >= (topScore * 0.7).round()) {
      // Mélange les deux pools pour plus de diversité
      final pool1 = _getPoolForTheme(winner);
      final pool2 = _getPoolForTheme(sorted[1].key);
      return [...pool1, ...pool2];
    }

    return _getPoolForTheme(winner);
  }

  // ─── STEMMING FRANÇAIS ───────────────────────────────────────────────────────
  // Supprime les suffixes courants pour matcher les pluriels et variantes

  static String _stemFr(String word) {
    const suffixes = [
      'ments', 'eurs', 'euses', 'istes', 'tions', 'iques', 'eries',
      'ment', 'euse', 'iste', 'tion', 'ique', 'erie',
      'aux', 'ers', 'ees', 'ies', 'es', 's', 'x',
    ];
    for (final sfx in suffixes) {
      if (word.length > sfx.length + 3 && word.endsWith(sfx)) {
        return word.substring(0, word.length - sfx.length);
      }
    }
    return word;
  }

  // ─── LOOKUP HASHTAG AVANCÉ ───────────────────────────────────────────────────
  // 1. Exact  2. Stemmé  3. Préfixe fuzzy (min 5 chars)

  static String? _lookupHashtag(String raw) {
    // 1. Exact
    var theme = _hashtagToTheme[raw];
    if (theme != null) return theme;

    // 2. Stemmé (blagues → blague, chansons → chanson)
    final stemmed = _stemFr(raw);
    if (stemmed != raw) {
      theme = _hashtagToTheme[stemmed];
      if (theme != null) return theme;
    }

    // 3. Préfixe fuzzy : le hashtag commence par une clé connue (min 5 chars)
    if (raw.length >= 5) {
      for (final entry in _hashtagToTheme.entries) {
        final key = entry.key;
        if (key.length >= 4 && raw.startsWith(key) && (raw.length - key.length) <= 3) {
          return entry.value;
        }
        if (key.length >= 5 && key.startsWith(raw) && (key.length - raw.length) <= 3) {
          return entry.value;
        }
      }
    }
    return null;
  }

  // ─── HELPERS ────────────────────────────────────────────────────────────────

  static List<String> _getPoolForTheme(String theme) {
    if (_byPostType.containsKey(theme)) return _byPostType[theme]!;
    if (_byTheme.containsKey(theme)) return _byTheme[theme]!;
    if (_byEmotion.containsKey(theme)) return _byEmotion[theme]!;
    return _general;
  }

  static List<String> _buildEmotionMixedPool() {
    final pool = <String>[];
    for (final emotionList in _byEmotion.values) {
      final shuffled = List<String>.from(emotionList)..shuffle(_rng);
      pool.addAll(shuffled.take(2));
    }
    return pool;
  }

  static List<String> _extractHashtags(String text) {
    final matches = RegExp(r'#\w+').allMatches(text);
    return matches.map((m) => m.group(0)!.toLowerCase()).toList();
  }

  static String _detectEmotion(String text) {
    final counts = <String, int>{};
    for (final entry in _emojiToEmotion.entries) {
      if (text.contains(entry.key)) {
        counts[entry.value] = (counts[entry.value] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return '';
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  static String _normalize(String input) {
    const with_ = 'àáâãäåçèéêëìíîïñòóôõöùúûüýÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖÙÚÛÜÝ';
    const with__ = 'aaaaaaceeeeiiiinooooouuuuyaaaaaaceeeeiiiinooooouuuuy';
    final buf = StringBuffer();
    for (final rune in input.runes) {
      final c = String.fromCharCode(rune);
      final idx = with_.indexOf(c);
      buf.write(idx >= 0 ? with__[idx] : c.toLowerCase());
    }
    return buf.toString();
  }
}
