// Guides rédigés pour SlashAtlas (FR/EN). Chaque guide : slug par langue, catégorie et commande liées, texte.
// Une section = [titre, [paragraphes ou listes]] ; un tableau dans la liste devient une liste à puces.
export const GUIDES = [
  {
    slug: { fr: 'photographier-un-produit', en: 'photograph-a-product' }, cat: 'produit', cmd: 'productglow', min: 4,
    fr: {
      title: 'Photographier un produit pour une affiche IA', desc: 'Lumière, fond, angle, netteté : les gestes simples pour une photo de produit que l’IA saura mettre en valeur dans une affiche.',
      intro: 'Une affiche IA ne vaut jamais plus que la photo de départ. La bonne nouvelle : pas besoin d’un studio. Un téléphone, une fenêtre et cinq minutes suffisent, si l’on évite quelques pièges.',
      sections: [
        ['1. Choisissez la lumière avant tout', ['Placez le produit près d’une fenêtre, de côté, en lumière du jour. Évitez le flash : il écrase les volumes et crée des reflets durs. Si le soleil tape directement, tamisez avec un voilage ou un papier blanc : la lumière douce donne des ombres douces, et l’IA les reproduit mieux.']],
        ['2. Un fond simple, un produit au centre', ['Un mur uni, une table claire ou une feuille de papier suffit. Plus le fond est chargé, plus l’IA hésite sur ce qu’il faut garder. Laissez de l’air autour du produit : c’est cet espace qui recevra le titre, le prix ou le logo.']],
        ['3. Montrez le produit tel qu’il est', ['Une affiche IA peut changer l’ambiance, jamais la vérité. Photographiez l’étiquette, la forme et les couleurs réelles : c’est ce que vos clients retrouveront à la livraison. Une commande bien écrite demande à l’IA de garder le produit identique ; encore faut-il qu’il soit lisible sur la photo.']],
        ['4. Quelques réglages qui comptent', [['Tenez le téléphone à hauteur du produit, pas en plongée.', 'Nettoyez l’objectif et le produit (traces de doigts, poussière).', 'Touchez l’écran sur le produit pour fixer la netteté.', 'Prenez 3 angles : face, trois quarts, détail.', 'Gardez la photo originale, sans filtre ni recadrage excessif.']]],
        ['5. Plusieurs produits ? Alignez-les', ['Pour un lot ou une gamme, alignez les produits sur la même ligne, du plus petit au plus grand, avec un léger espace entre eux. Dans les commandes de SlashAtlas, choisissez « Plusieurs » : la consigne s’adapte à l’ensemble.']],
      ],
    },
    en: {
      title: 'How to photograph a product for an AI poster', desc: 'Light, background, angle, sharpness: simple habits for a product photo that an AI can turn into a great poster.',
      intro: 'An AI poster is only ever as good as the photo it starts from. The good news: you do not need a studio. A phone, a window and five minutes are enough, as long as you avoid a few traps.',
      sections: [
        ['1. Get the light right first', ['Put the product next to a window, to the side, in daylight. Skip the flash: it flattens shapes and creates harsh reflections. If the sun hits directly, soften it with a sheer curtain or a sheet of white paper. Soft light gives soft shadows, and AI reproduces them better.']],
        ['2. A simple background, the product in the middle', ['A plain wall, a light table or a sheet of paper is enough. The busier the background, the more the AI has to guess what to keep. Leave some air around the product: that space is where the title, the price or the logo will go.']],
        ['3. Show the product as it really is', ['An AI poster can change the mood, never the truth. Photograph the real label, shape and colors: that is what your customers will find at delivery. A well-written command asks the AI to keep the product identical, but the product still has to be readable in the photo.']],
        ['4. A few settings that matter', [['Hold the phone at the product’s height, not looking down on it.', 'Wipe the lens and the product (fingerprints, dust).', 'Tap the screen on the product to lock focus.', 'Take 3 angles: front, three-quarter, close-up.', 'Keep the original photo, no filter and no heavy cropping.']]],
        ['5. Several products? Line them up', ['For a set or a range, line the products up on one row, smallest to largest, with a small gap between them. In SlashAtlas commands, choose “Several”: the instruction adapts to the whole group.']],
      ],
    },
  },
  {
    slug: { fr: 'ecrire-un-bon-prompt-affiche', en: 'write-a-good-poster-prompt' }, cat: 'reseaux', cmd: 'splashshot', min: 5,
    fr: {
      title: 'Écrire un bon prompt pour une affiche IA', desc: 'La structure d’un prompt qui marche du premier coup : sujet, lumière, composition, espace pour le texte et ce qu’il ne faut pas changer.',
      intro: 'Beaucoup de gens réécrivent dix fois le même prompt. Le problème est rarement la longueur : c’est le manque de structure. Voici l’ordre qui donne les meilleurs résultats.',
      sections: [
        ['1. Dites ce qu’on voit', ['Commencez par le sujet et ce qu’il fait : « le flacon de crème, posé seul au centre ». Une phrase concrète vaut mieux que des adjectifs vagues comme « beau » ou « professionnel », que l’IA interprète à sa façon.']],
        ['2. Décrivez la lumière et le fond', ['La lumière change tout : « lueur douce derrière le produit », « fond sombre dégradé », « lumière de fin de journée ». Choisissez une seule ambiance ; mélanger trois styles produit un résultat moyen.']],
        ['3. Prévoyez la place du texte', ['Si l’affiche doit porter un titre ou un prix, demandez « espace libre en haut » ou « bandeau uni en bas ». Écrivez le texte vous-même ensuite : les IA se trompent encore souvent sur les lettres, mieux vaut ne pas leur en demander.']],
        ['4. Dites ce qu’il ne faut pas toucher', ['« Garde le produit parfaitement identique : forme, couleurs, étiquette. N’ajoute ni texte ni prix. » Cette phrase évite que l’IA réinvente votre produit. Les commandes de SlashAtlas l’incluent déjà.']],
        ['5. Itérez avec une seule correction à la fois', [['Une demande = un changement : « fond plus clair », puis « ombre plus douce ».', 'Gardez la version qui marche et corrigez-la au lieu de tout recommencer.', 'Notez les formulations qui fonctionnent pour les réutiliser.']]],
        ['Gagner du temps', ['Une commande prête à l’emploi réunit ces cinq points. Vous la copiez, vous la collez avec votre photo, et vous ne gardez à écrire que le nom du produit. C’est le principe de SlashAtlas.']],
      ],
    },
    en: {
      title: 'How to write a good AI poster prompt', desc: 'The structure of a prompt that works the first time: subject, light, composition, room for text and what must not change.',
      intro: 'Many people rewrite the same prompt ten times. The problem is rarely length: it is structure. Here is the order that gives the best results.',
      sections: [
        ['1. Say what we see', ['Start with the subject and what it is doing: “the cream bottle, alone in the center”. One concrete sentence beats vague adjectives like “beautiful” or “professional”, which the AI interprets its own way.']],
        ['2. Describe the light and the background', ['Light changes everything: “soft glow behind the product”, “dark gradient background”, “late-afternoon light”. Pick one mood; mixing three styles gives an average result.']],
        ['3. Plan room for the text', ['If the poster needs a title or a price, ask for “free space at the top” or “a plain band at the bottom”. Add the text yourself afterwards: AI still often gets letters wrong, so it is better not to ask it for any.']],
        ['4. Say what must not be touched', ['“Keep the product perfectly identical: shape, colors, label. Do not add any text or price.” This sentence stops the AI from reinventing your product. SlashAtlas commands already include it.']],
        ['5. Iterate with one correction at a time', [['One request = one change: “lighter background”, then “softer shadow”.', 'Keep the version that works and fix it instead of starting over.', 'Note the wordings that work so you can reuse them.']]],
        ['Saving time', ['A ready-made command combines these five points. You copy it, paste it with your photo, and the only thing left to write is the product name. That is the idea behind SlashAtlas.']],
      ],
    },
  },
  {
    slug: { fr: 'erreurs-affiche-ia', en: 'ai-poster-mistakes' }, cat: 'produit', cmd: 'splashshot', min: 4,
    fr: {
      title: '7 erreurs qui gâchent une affiche publicitaire IA', desc: 'Texte illisible, produit déformé, trop d’éléments : les sept erreurs les plus courantes dans une affiche créée avec l’IA, et comment les éviter.',
      intro: 'Une affiche IA ratée a presque toujours la même cause. Voici les sept erreurs que l’on rencontre le plus souvent, avec le correctif.',
      sections: [
        ['1. Demander du texte à l’IA', ['Prix, slogan, numéro de téléphone : les IA se trompent encore sur les lettres et les chiffres. Générez l’image sans texte, puis ajoutez le texte dans une application de retouche ou de mise en page.']],
        ['2. Laisser l’IA changer le produit', ['Si la bouteille change de forme ou de couleur, vos clients se sentiront trompés. Demandez explicitement de garder le produit identique, et vérifiez le résultat contre la photo.']],
        ['3. Trop d’éléments à l’image', ['Un produit, une ambiance, un message. Dès qu’on empile fleurs, confettis et trois couleurs vives, l’œil ne sait plus où se poser.']],
        ['4. Oublier l’espace pour le titre', ['Une affiche sans zone calme ne laisse nulle part où écrire. Demandez un espace libre dès la génération.']],
        ['5. Un mauvais format pour la plateforme', ['Une affiche carrée recadrée en story perd ses bords. Choisissez le format avant de générer (voir notre guide sur les formats).']],
        ['6. Une photo de départ trop sombre ou floue', ['L’IA ne rattrape pas un flou : elle l’invente. Reprenez la photo près d’une fenêtre avant de relancer.']],
        ['7. Ne pas signaler l’image comme générée par IA quand c’est requis', ['Certaines plateformes, et certains pays, demandent d’indiquer qu’une image est générée par IA, surtout quand elle paraît réaliste. Renseignez-vous avant de publier, et indiquez-le si nécessaire.']],
      ],
    },
    en: {
      title: '7 mistakes that ruin an AI advertising poster', desc: 'Unreadable text, a distorted product, too many elements: the seven most common mistakes in an AI-made poster, and how to avoid them.',
      intro: 'A failed AI poster almost always has the same cause. Here are the seven mistakes we see most often, with the fix.',
      sections: [
        ['1. Asking the AI for text', ['Prices, slogans, phone numbers: AI still gets letters and numbers wrong. Generate the image without text, then add the text in an editing or layout app.']],
        ['2. Letting the AI change the product', ['If the bottle changes shape or color, your customers will feel misled. Explicitly ask to keep the product identical, and check the result against the photo.']],
        ['3. Too many elements in the picture', ['One product, one mood, one message. As soon as you stack flowers, confetti and three bright colors, the eye no longer knows where to land.']],
        ['4. Forgetting room for the title', ['A poster without a calm area leaves nowhere to write. Ask for free space at generation time.']],
        ['5. The wrong format for the platform', ['A square poster cropped into a story loses its edges. Pick the format before generating (see our guide on formats).']],
        ['6. A starting photo that is too dark or blurry', ['AI does not fix blur: it invents. Retake the photo next to a window before trying again.']],
        ['7. Not labeling the image as AI-generated when required', ['Some platforms, and some countries, ask you to say when an image is AI-generated, especially when it looks realistic. Check the rules before publishing, and label it when needed.']],
      ],
    },
  },
  {
    slug: { fr: 'formats-affiche-reseaux-sociaux', en: 'poster-sizes-social-media' }, cat: 'reseaux', cmd: 'reelcover', min: 4,
    fr: {
      title: 'Quel format d’affiche pour chaque réseau social ?', desc: 'Carré, 4:5, vertical 9:16 ou paysage : le bon format selon la plateforme, et comment garder le texte lisible dans les zones sûres.',
      intro: 'Une même affiche ne convient pas partout. Choisir le format avant de générer évite les recadrages qui coupent le produit ou le texte.',
      sections: [
        ['Les formats les plus courants', [['Fil Instagram et Facebook : 4:5 (par exemple 1080 × 1350 px) occupe le plus de place à l’écran ; le carré 1:1 (1080 × 1080) reste universel.', 'Stories, Reels, TikTok et statut WhatsApp : vertical 9:16 (1080 × 1920 px).', 'Miniature YouTube et bannière paysage : 16:9 (1280 × 720 px).', 'Affiche imprimée : demandez le format 4:5 ou 3:2 et agrandissez ensuite avec un outil adapté.']]],
        ['Gardez le texte dans la zone sûre', ['En vertical, l’interface de l’application couvre le haut et le bas de l’écran. Gardez titre et prix dans la zone centrale, en laissant environ 15 % de marge en haut et 20 % en bas.']],
        ['Un format, une version', ['Plutôt que de recadrer une seule image partout, générez une version par format. Dans SlashAtlas, chaque commande indique le format conseillé, et vous pouvez le préciser dans votre demande.']],
        ['Vérifiez sur téléphone', ['Regardez toujours l’affiche à la taille d’un écran de téléphone avant de publier : si le texte est lisible à bout de bras, il le sera pour vos clients.']],
      ],
    },
    en: {
      title: 'Which poster format for each social network?', desc: 'Square, 4:5, vertical 9:16 or landscape: the right format for each platform, and how to keep text readable inside safe areas.',
      intro: 'One poster does not fit everywhere. Picking the format before generating avoids crops that cut off the product or the text.',
      sections: [
        ['The most common formats', [['Instagram and Facebook feed: 4:5 (for example 1080 × 1350 px) takes the most room on screen; square 1:1 (1080 × 1080) stays universal.', 'Stories, Reels, TikTok and WhatsApp status: vertical 9:16 (1080 × 1920 px).', 'YouTube thumbnail and landscape banner: 16:9 (1280 × 720 px).', 'Printed poster: ask for 4:5 or 3:2, then enlarge with a suitable tool.']]],
        ['Keep the text inside the safe area', ['In vertical formats, the app interface covers the top and bottom of the screen. Keep the title and price in the middle, leaving about 15% margin at the top and 20% at the bottom.']],
        ['One format, one version', ['Rather than cropping a single image everywhere, generate one version per format. In SlashAtlas each command shows a recommended format, and you can specify it in your request.']],
        ['Check on a phone', ['Always view the poster at phone-screen size before publishing: if the text is readable at arm’s length, it will be readable for your customers.']],
      ],
    },
  },
  {
    slug: { fr: 'photo-plat-restaurant', en: 'restaurant-food-photos' }, cat: 'food', cmd: 'menuhero', min: 4,
    fr: {
      title: 'Photographier un plat pour une affiche de restaurant', desc: 'Lumière, angle, vapeur, accessoires : comment photographier un plat avec un téléphone avant d’en faire une affiche ou un menu.',
      intro: 'Un plat qui donne faim se joue en quelques gestes. Voici une méthode simple pour un restaurant, un maquis, un food truck ou une livraison à domicile.',
      sections: [
        ['1. La lumière du jour avant tout', ['Installez-vous près d’une fenêtre, jamais sous une lumière jaune de plafond. Éteignez les néons : ils donnent une teinte verdâtre à la nourriture.']],
        ['2. Choisissez l’angle selon le plat', [['De dessus (à 90°) pour les assiettes plates : pizzas, salades, bols.', 'En légère plongée (45°) pour les plats avec du relief : brochettes, sauce, riz.', 'De face pour les plats hauts : burgers, gâteaux, sandwiches.']]],
        ['3. La vapeur et la fraîcheur', ['Photographiez dans les premières minutes, quand le plat fume et que les sauces brillent. Quelques gouttes d’huile ou d’eau au pinceau redonnent de l’éclat aux légumes.']],
        ['4. Peu d’accessoires, un fond sobre', ['Une planche en bois, une nappe unie et un couvert suffisent. Laissez le plat être la vedette ; retirez les verres et bouteilles inutiles du cadre.']],
        ['5. Ensuite, l’affiche', ['Choisissez la commande « plat vedette » ou « menu du jour » sur SlashAtlas, collez-la avec la photo, puis ajoutez prix et horaires vous-même. Ne promettez jamais sur l’affiche un plat différent de ce que vous servez.']],
      ],
    },
    en: {
      title: 'How to photograph a dish for a restaurant poster', desc: 'Light, angle, steam, props: how to shoot a dish with a phone before turning it into a poster or a menu.',
      intro: 'A dish that makes people hungry comes down to a few moves. Here is a simple method for a restaurant, a street-food spot, a food truck or home delivery.',
      sections: [
        ['1. Daylight above all', ['Set up next to a window, never under a yellow ceiling light. Turn off fluorescent tubes: they give food a greenish tint.']],
        ['2. Pick the angle for the dish', [['From above (90°) for flat plates: pizzas, salads, bowls.', 'Slightly from above (45°) for dishes with texture: skewers, sauce, rice.', 'Straight on for tall dishes: burgers, cakes, sandwiches.']]],
        ['3. Steam and freshness', ['Shoot in the first minutes, while the dish is steaming and the sauces are shining. A few drops of oil or water, applied with a brush, bring vegetables back to life.']],
        ['4. Few props, a plain background', ['A wooden board, a plain tablecloth and a fork are enough. Let the dish be the star; remove unneeded glasses and bottles from the frame.']],
        ['5. Then, the poster', ['Pick the “hero dish” or “menu of the day” command on SlashAtlas, paste it with the photo, then add price and opening hours yourself. Never promise a dish on the poster that differs from what you serve.']],
      ],
    },
  },
  {
    slug: { fr: 'photos-annonce-immobiliere', en: 'real-estate-listing-photos' }, cat: 'immobilier', cmd: 'openhouse', min: 4,
    fr: {
      title: 'Photos d’une annonce immobilière : les bons réflexes', desc: 'Ordre des pièces, lumière, façade, honnêteté : comment préparer des photos de bien à vendre ou à louer avant d’en faire une affiche IA.',
      intro: 'Une annonce se juge en deux secondes. Une bonne photo fait venir plus de visiteurs, et une affiche bien faite les retient.',
      sections: [
        ['1. Préparez le bien', ['Rangez, dégagez les plans de travail, ouvrez volets et rideaux. Un bien vide de désordre paraît plus grand, avec ou sans IA.']],
        ['2. Photographiez dans la lumière du jour', ['Visez la fin de matinée ou le milieu d’après-midi. Allumez les lumières intérieures pour réchauffer les ambiances, mais gardez la fenêtre ouverte sur le jour.']],
        ['3. Un ordre qui raconte la visite', [['La façade, de jour, ciel dégagé.', 'L’entrée et le séjour.', 'La cuisine, puis les chambres.', 'La salle de bain, la terrasse ou le jardin.', 'Un plan large d’ensemble en dernier.']]],
        ['4. Restez fidèle au bien', ['Une IA peut nettoyer le ciel ou adoucir la lumière. Elle ne doit pas ajouter une piscine, agrandir une pièce ou masquer un défaut visible : c’est trompeur, et c’est interdit dans plusieurs pays. Montrez le bien tel qu’il est, sous son meilleur jour.']],
        ['5. L’affiche', ['Avec la commande « porte ouverte » ou « façade en plein jour » de SlashAtlas, vous obtenez une affiche prête à ajouter l’adresse, le prix et le contact. Mentionnez toujours les informations exactes : surface, loyer ou prix, date de visite.']],
      ],
    },
    en: {
      title: 'Real estate listing photos: the right habits', desc: 'Room order, light, facade, honesty: how to prepare photos of a property for sale or rent before turning them into an AI poster.',
      intro: 'A listing is judged in two seconds. A good photo brings more visitors, and a well-made poster keeps them.',
      sections: [
        ['1. Prepare the property', ['Tidy up, clear the worktops, open shutters and curtains. A space free of clutter looks bigger, with or without AI.']],
        ['2. Shoot in daylight', ['Aim for late morning or mid-afternoon. Turn on interior lights to warm the mood, but keep the window open to the daylight.']],
        ['3. An order that tells the visit', [['The facade, in daylight, clear sky.', 'The entrance and the living room.', 'The kitchen, then the bedrooms.', 'The bathroom, the terrace or the garden.', 'A wide overview shot last.']]],
        ['4. Stay faithful to the property', ['An AI can clean up the sky or soften the light. It must not add a pool, enlarge a room or hide a visible flaw: that is misleading, and illegal in several countries. Show the property as it is, at its best.']],
        ['5. The poster', ['With SlashAtlas’s “open house” or “facade in daylight” command, you get a poster ready for the address, price and contact. Always state accurate information: surface area, rent or price, visit date.']],
      ],
    },
  },
];
