// Commandes « produits du quotidien que les femmes vendent et achètent le plus » (maison, cuisine, linge, rangement, salle de bain, ménage, cadeaux, accessoires)
// et « styles de décoration » (21 octobre 2026). Chaque produit a sa catégorie, des mots-clés de recherche (synonymes FR + EN, noms courants) et une photo
// de départ (SRC) pour la génération des aperçus. Les aperçus ne sont PAS encore générés : le site affiche l'aperçu d'attente (noImage) jusqu'à ce que les
// fichiers static/img/c/{slug}-t.webp et {slug}-apres.webp existent (voir SUIVI_IMAGES.md, « À faire après recharge du compte »).
//
// Produit : [slug, format, titre FR, étiquette FR, titre EN, étiquette EN, mise en scène FR, mise en scène EN, photo de départ FR, mots-clés]
// Le reste (description, commande complète) est composé plus bas à partir de ces champs et d'une trame par catégorie.

// Catégories ajoutées au site (voir CATEGORIES de data.mjs) et leur formule de description
const CAT = {
  decoint: { fr: 'de décoration d’intérieur', en: 'interior decoration' },
  cuisine: { fr: 'de cuisine et d’art de la table', en: 'kitchen and tableware' },
  rangement: { fr: 'de rangement et d’organisation', en: 'storage and organization' },
  literie: { fr: 'de literie et de linge de maison', en: 'bedding and home linen' },
  bain: { fr: 'de salle de bain', en: 'bathroom' },
  menage: { fr: 'd’entretien et de ménage', en: 'cleaning and household' },
  cadeaux: { fr: 'de cadeaux et de décoration de fête', en: 'gifts and party decoration' },
  beaute: { fr: 'de beauté et d’accessoires', en: 'beauty and accessories' },
};

const ITEMS = {
  // ── Décoration d'intérieur ──
  decoint: [
    ['tapissalon', '4:5', 'Tapis de salon', 'Tapis', 'Living room rug', 'Rug', 'posé au centre d’un salon lumineux, canapé et plante flous en arrière-plan', 'laid in the middle of a bright living room, sofa and plant blurred in the background', 'Un tapis à motifs posé sur le carrelage d’un salon, avec un canapé derrière.', 'tapis moquette carpet rug salon sol deco'],
    ['nappestable', '4:5', 'Nappes de table', 'Nappes', 'Tablecloths', 'Tablecloths', 'dressée sur une table à manger, assiettes et verres posés, lumière chaude de fin de journée', 'spread over a dining table, plates and glasses set out, warm late-day light', 'Une nappe en tissu pliée à moitié sur une table de salle à manger.', 'nappe tablecloth table repas wax tissu'],
    ['housescoussins', '1:1', 'Housses de coussins', 'Coussins', 'Cushion covers', 'Cushions', 'sur des coussins posés sur un canapé, couleurs assorties, plaid plié à côté', 'on cushions placed on a sofa, matching colors, a folded throw beside them', 'Trois housses de coussin de couleurs différentes posées sur un canapé.', 'coussin housse cushion pillow canape salon deco'],
    ['fleursartificielles', '4:5', 'Fleurs artificielles', 'Fleurs', 'Artificial flowers', 'Flowers', 'en bouquet dans un vase sur une console d’entrée, lumière douce de fenêtre', 'as a bouquet in a vase on an entry console, soft window light', 'Un bouquet de fleurs artificielles colorées posé sur une table.', 'fleur bouquet artificielle plastique soie flowers fake deco'],
    ['vasesdeco', '4:5', 'Vases décoratifs', 'Vases', 'Decorative vases', 'Vases', 'posés sur un meuble de salon, avec quelques tiges, lumière douce et fond clair', 'placed on a living room cabinet with a few stems, soft light and a light background', 'Deux vases en céramique posés sur une étagère.', 'vase pot fleurs ceramique verre deco'],
    ['tableauxmuraux', '3:2', 'Tableaux muraux', 'Tableaux', 'Wall art', 'Wall art', 'accrochés au mur d’un salon au-dessus d’un canapé, cadres bien alignés, lumière douce', 'hung on a living room wall above a sofa, frames neatly aligned, soft light', 'Trois tableaux encadrés posés contre un mur blanc.', 'tableau cadre mural peinture affiche wall art frame deco'],
    ['horlogesmurales', '1:1', 'Horloges murales', 'Horloges', 'Wall clocks', 'Clocks', 'accrochée sur un mur de salon ou de cuisine, ambiance claire et soignée', 'hung on a living room or kitchen wall, a bright and tidy mood', 'Une horloge ronde accrochée à un mur blanc.', 'horloge pendule clock mur deco'],
    ['guirlandeslumineuses', '4:5', 'Guirlandes lumineuses', 'Guirlandes', 'String lights', 'String lights', 'allumées le soir autour d’un mur ou d’une fenêtre, ambiance chaleureuse et festive', 'lit in the evening around a wall or window, a warm festive mood', 'Une guirlande lumineuse éteinte posée sur un lit.', 'guirlande lumiere led fairy lights noel fete deco ambiance'],
    ['desodorisantsmaison', '1:1', 'Désodorisants d’intérieur', 'Désodorisants', 'Home air fresheners', 'Fresheners', 'posés sur un meuble d’entrée, avec quelques fleurs, ambiance fraîche et propre', 'placed on an entry cabinet with a few flowers, a fresh and clean mood', 'Un désodorisant en spray et un diffuseur posés sur une table.', 'desodorisant parfum interieur spray gel air freshener odeur'],
    ['dessuslit', '4:5', 'Dessus de lit', 'Dessus de lit', 'Bedspreads', 'Bedspread', 'sur un lit fait avec soin, coussins assortis, lumière douce du matin', 'on a carefully made bed, matching cushions, soft morning light', 'Un dessus de lit plié au pied d’un lit.', 'dessus de lit couvre lit bedspread chambre couette'],
    ['housesfauteuils', '4:5', 'Housses de fauteuils', 'Housses', 'Armchair covers', 'Covers', 'ajustée sur un fauteuil de salon, tissu bien tendu, ambiance de salon soigné', 'fitted on a living room armchair, fabric nicely stretched, a tidy living room mood', 'Une housse de fauteuil pliée posée sur un fauteuil.', 'housse fauteuil canape protection armchair sofa cover'],
  ],

  // ── Cuisine et art de la table ──
  cuisine: [
    ['couverts', '1:1', 'Cuillères et fourchettes', 'Couverts', 'Spoons and forks', 'Cutlery', 'rangés dans un ravier ou alignés sur une table, métal brillant, lumière douce', 'neatly stored in a tray or lined up on a table, shiny metal, soft light', 'Des cuillères et des fourchettes en inox posées en vrac sur un plan de travail.', 'cuillere fourchette couvert cutlery spoon fork inox vaisselle'],
    ['louches', '1:1', 'Louches', 'Louches', 'Ladles', 'Ladles', 'accrochées près d’un fourneau ou posées dans une casserole fumante', 'hanging near a stove or resting in a steaming pot', 'Deux louches en inox posées sur un plan de travail.', 'louche ladle cuisine soupe sauce'],
    ['couteauxcuisine', '1:1', 'Couteaux de cuisine', 'Couteaux', 'Kitchen knives', 'Knives', 'sur une planche à découper, légumes frais à côté, lumière nette', 'on a chopping board with fresh vegetables beside them, crisp light', 'Un couteau de cuisine et un couteau à pain posés sur un plan de travail.', 'couteau knife cuisine lame decoupe'],
    ['spatules', '1:1', 'Spatules', 'Spatules', 'Spatulas', 'Spatulas', 'dans un pot à ustensiles près d’un fourneau, bois et silicone bien nets', 'in a utensil jar near a stove, wood and silicone crisp and clean', 'Trois spatules en bois et en silicone posées sur un plan de travail.', 'spatule spatula cuillere bois silicone cuisine ustensile'],
    ['passoires', '1:1', 'Passoires', 'Passoires', 'Strainers', 'Strainers', 'dans un évier propre ou tenues au-dessus d’un plat de pâtes, vapeur légère', 'in a clean sink or held over a dish of pasta, light steam', 'Une passoire en métal posée dans un évier.', 'passoire strainer colander egouttoir cuisine'],
    ['bolscuisine', '1:1', 'Bols', 'Bols', 'Bowls', 'Bowls', 'empilés sur une table claire, un bol rempli de fruits ou de riz, lumière douce', 'stacked on a light table, one bowl filled with fruit or rice, soft light', 'Quatre bols en céramique empilés sur une table.', 'bol bowl vaisselle ceramique soupe petit dejeuner'],
    ['tassesverres', '1:1', 'Tasses et verres', 'Tasses', 'Cups and glasses', 'Cups', 'dressés sur un plateau, une boisson chaude et un jus servis, lumière chaleureuse', 'set on a tray, a hot drink and a juice served, warm light', 'Des tasses et des verres alignés sur une étagère.', 'tasse verre mug cup glass boisson the cafe vaisselle'],
    ['plateauservice', '4:5', 'Plateaux de service', 'Plateaux', 'Serving trays', 'Trays', 'chargés de verres et de petits gâteaux, posés sur une table de salon', 'loaded with glasses and small cakes, set on a living room table', 'Un plateau en bois vide posé sur une table.', 'plateau tray service salon reception vaisselle'],
    ['planchesdecouper', '1:1', 'Planches à découper', 'Planches', 'Chopping boards', 'Boards', 'avec des légumes frais en train d’être coupés, bois chaleureux, lumière naturelle', 'with fresh vegetables being cut, warm wood, natural light', 'Une planche à découper en bois posée sur un plan de travail.', 'planche decouper chopping board bois cuisine'],
    ['recipientsalim', '1:1', 'Récipients alimentaires', 'Récipients', 'Food containers', 'Containers', 'remplis de restes de repas bien rangés dans un réfrigérateur ouvert', 'filled with neatly stored leftovers in an open fridge', 'Une pile de récipients en plastique avec couvercles posée sur un plan de travail.', 'recipient boite tupperware lunch box conservation alimentaire food container'],
    ['bouteillesdeau', '4:5', 'Bouteilles d’eau', 'Bouteilles', 'Water bottles', 'Bottles', 'posées sur un bureau ou dans un sac de sport, gouttelettes fraîches, ambiance dynamique', 'standing on a desk or in a gym bag, fresh droplets, an energetic mood', 'Une bouteille d’eau réutilisable posée sur une table.', 'bouteille eau gourde water bottle sport hydratation'],
    ['thermosisotherme', '4:5', 'Thermos', 'Thermos', 'Thermos flasks', 'Thermos', 'posé sur une table avec une tasse fumante à côté, ambiance chaleureuse du matin', 'on a table with a steaming cup beside it, a warm morning mood', 'Un thermos en inox posé sur un plan de travail.', 'thermos isotherme flask the cafe chaud boisson'],
    ['boitesepices', '1:1', 'Boîtes à épices', 'Épices', 'Spice jars', 'Spices', 'alignées sur une étagère de cuisine, épices colorées visibles, lumière chaleureuse', 'lined up on a kitchen shelf, colorful spices visible, warm light', 'Quatre pots à épices en verre alignés sur une étagère.', 'epice spice pot bocal assaisonnement cuisine'],
    ['egouttoirs', '1:1', 'Égouttoirs à vaisselle', 'Égouttoirs', 'Dish racks', 'Dish racks', 'à côté d’un évier, assiettes propres et verres qui sèchent, lumière de cuisine', 'beside a sink, clean plates and glasses drying, kitchen light', 'Un égouttoir à vaisselle vide posé à côté d’un évier.', 'egouttoir vaisselle dish rack evier cuisine'],
    ['corbeillepain', '1:1', 'Corbeilles à pain', 'Corbeilles à pain', 'Bread baskets', 'Bread baskets', 'garnies de pain frais et recouvertes d’un linge, posées sur une table de petit déjeuner', 'filled with fresh bread and covered with a cloth, set on a breakfast table', 'Une corbeille en osier posée sur une table.', 'corbeille pain bread basket panier osier'],
    ['saladiers', '1:1', 'Saladiers', 'Saladiers', 'Salad bowls', 'Salad bowls', 'remplis d’une salade colorée, posés au centre d’une table dressée', 'filled with a colorful salad, set in the middle of a laid table', 'Un grand saladier en verre posé sur une table.', 'saladier salad bowl plat service verre'],
    ['bolsfruits', '1:1', 'Bols à fruits', 'Bols à fruits', 'Fruit bowls', 'Fruit bowls', 'débordants de fruits frais, posés sur une table de cuisine claire', 'overflowing with fresh fruit, set on a light kitchen table', 'Un bol en céramique vide posé sur une table de cuisine.', 'bol fruit corbeille fruit bowl table'],
    ['potseau', '4:5', 'Pots à eau', 'Pots à eau', 'Water pitchers', 'Pitchers', 'posés sur une table dressée, remplis d’eau fraîche avec des tranches de citron', 'set on a laid table, filled with fresh water and lemon slices', 'Un pot à eau en plastique posé sur une table.', 'pot eau pichet jug water pitcher boisson table'],
    ['carafes', '4:5', 'Carafes', 'Carafes', 'Carafes', 'Carafes', 'remplies de jus ou d’eau, posées sur un plateau avec deux verres, lumière douce', 'filled with juice or water, set on a tray with two glasses, soft light', 'Une carafe en verre vide posée sur une table.', 'carafe pichet juice jus eau verre service'],
    ['setsdetable', '4:5', 'Sets de table', 'Sets de table', 'Placemats', 'Placemats', 'posés sur une table avec assiettes et couverts alignés, couleurs assorties', 'laid on a table with plates and cutlery lined up, matching colors', 'Quatre sets de table en tissu empilés sur une table.', 'set de table placemat napperon repas'],
    ['dessousplat', '1:1', 'Dessous-de-plat', 'Dessous-de-plat', 'Trivets', 'Trivets', 'sous un plat chaud posé au centre d’une table, vapeur légère', 'under a hot dish in the middle of a table, light steam', 'Un dessous-de-plat en liège posé sur une table.', 'dessous de plat trivet liege bois table chaud'],
    ['dessousverre', '1:1', 'Dessous-de-verre', 'Dessous-de-verre', 'Coasters', 'Coasters', 'sous des verres sur une table basse, ambiance détendue de salon', 'under glasses on a coffee table, a relaxed living room mood', 'Quatre dessous-de-verre posés sur une table basse.', 'dessous de verre coaster table basse boisson'],
    ['serviettestable', '1:1', 'Serviettes de table', 'Serviettes de table', 'Table napkins', 'Napkins', 'pliées avec soin sur des assiettes, table de fête élégante', 'neatly folded on plates, an elegant festive table', 'Des serviettes de table en papier et en tissu posées sur une table.', 'serviette table napkin tissu papier repas fete'],
  ],

  // ── Rangement et organisation ──
  rangement: [
    ['panierrangement', '4:5', 'Paniers de rangement', 'Paniers', 'Storage baskets', 'Baskets', 'sur une étagère, remplis de linge et de petits objets, chambre rangée et lumineuse', 'on a shelf, filled with linen and small items, a tidy bright bedroom', 'Trois paniers en tissu posés par terre dans une chambre.', 'panier rangement basket storage osier tissu chambre'],
    ['boiterangement', '4:5', 'Boîtes de rangement', 'Boîtes', 'Storage boxes', 'Boxes', 'empilées dans un placard ouvert, étiquettes vierges, placard bien organisé', 'stacked in an open closet, blank labels, a well-organized closet', 'Des boîtes de rangement en plastique empilées dans un coin.', 'boite rangement box storage plastique placard'],
    ['organisateurtiroir', '1:1', 'Organisateurs de tiroirs', 'Tiroirs', 'Drawer organizers', 'Drawers', 'dans un tiroir ouvert, petits objets rangés par cases, vue de dessus nette', 'in an open drawer, small items sorted into compartments, crisp top view', 'Un organisateur de tiroir vide posé sur une table.', 'organisateur tiroir drawer organizer separateur couverts'],
    ['rangechaussures', '4:5', 'Range-chaussures', 'Range-chaussures', 'Shoe racks', 'Shoe racks', 'dans une entrée, chaussures bien alignées sur les étages, ambiance ordonnée', 'in an entryway, shoes neatly lined up on the shelves, an orderly mood', 'Un meuble range-chaussures vide posé dans une entrée.', 'range chaussures shoe rack etagere chaussure entree'],
    ['portevetements', '4:5', 'Porte-vêtements', 'Porte-vêtements', 'Clothes racks', 'Clothes racks', 'garni de vêtements bien suspendus dans une chambre claire, lumière naturelle', 'filled with neatly hung clothes in a bright bedroom, natural light', 'Un portant à vêtements vide dans une chambre.', 'porte vetements portant clothes rack penderie dressing'],
    ['cintres', '1:1', 'Cintres', 'Cintres', 'Hangers', 'Hangers', 'accrochés à une tringle avec quelques vêtements, rendu net et organisé', 'hanging on a rail with a few clothes, a crisp organized look', 'Un lot de cintres en plastique posé sur un lit.', 'cintre hanger penderie vetement dressing'],
    ['panierlinge', '4:5', 'Paniers à linge', 'Linge', 'Laundry baskets', 'Laundry', 'dans une buanderie claire, rempli de linge plié, ambiance propre et fraîche', 'in a bright laundry room, filled with folded clothes, a clean fresh mood', 'Un panier à linge vide posé dans un coin de salle de bain.', 'panier linge laundry basket sale buanderie bac'],
    ['poubelles', '4:5', 'Poubelles', 'Poubelles', 'Trash bins', 'Bins', 'dans une cuisine ou une salle de bain propre, modèle net, sans odeur ni saleté visible', 'in a clean kitchen or bathroom, a crisp model, no visible dirt', 'Une poubelle à pédale posée dans une cuisine.', 'poubelle bin trash dechets pedale cuisine'],
    ['etageres', '4:5', 'Étagères', 'Étagères', 'Shelves', 'Shelves', 'contre un mur, garnies de livres, plantes et objets bien disposés, lumière douce', 'against a wall, filled with books, plants and neatly arranged objects, soft light', 'Une étagère à plusieurs niveaux vide contre un mur.', 'etagere shelf rayonnage meuble rangement livres'],
    ['organisateurmaquillage', '4:5', 'Organisateurs de maquillage', 'Maquillage', 'Makeup organizers', 'Makeup', 'sur une coiffeuse, pinceaux et rouges à lèvres rangés par cases, ambiance féminine et douce', 'on a vanity, brushes and lipsticks sorted into compartments, a soft feminine mood', 'Un organisateur de maquillage transparent posé sur une coiffeuse.', 'organisateur maquillage makeup organizer coiffeuse rangement cosmetique'],
    ['portebijoux', '4:5', 'Porte-bijoux', 'Porte-bijoux', 'Jewelry stands', 'Jewelry stands', 'sur une commode, colliers et bracelets suspendus avec élégance, lumière douce', 'on a dresser, necklaces and bracelets elegantly hung, soft light', 'Un porte-bijoux en bois vide posé sur une commode.', 'porte bijoux jewelry stand rangement collier bracelet presentoir'],
    ['rangesacs', '4:5', 'Range-sacs', 'Range-sacs', 'Bag organizers', 'Bag organizers', 'dans un placard ou accrochés à une porte, sacs à main bien alignés', 'in a closet or hung on a door, handbags neatly lined up', 'Un range-sacs en tissu suspendu à une porte, vide.', 'range sacs bag organizer sac a main placard suspendu'],
  ],

  // ── Literie et linge de maison ──
  literie: [
    ['drapslit', '4:5', 'Draps de lit', 'Draps', 'Bed sheets', 'Sheets', 'sur un lit fait avec soin, tissu lisse et propre, lumière douce du matin', 'on a carefully made bed, smooth clean fabric, soft morning light', 'Un drap plié posé sur un matelas nu.', 'drap lit sheet literie chambre linge coton'],
    ['taiesoreiller', '1:1', 'Taies d’oreiller', 'Taies', 'Pillowcases', 'Pillowcases', 'sur des oreillers bien gonflés au chevet d’un lit, tissu doux', 'on plump pillows at the head of a bed, soft fabric', 'Deux taies d’oreiller pliées posées sur un lit.', 'taie oreiller pillowcase literie chambre coton satin'],
    ['couvertures', '4:5', 'Couvertures', 'Couvertures', 'Blankets', 'Blankets', 'pliée au pied d’un lit ou sur un canapé, ambiance douce et chaude', 'folded at the foot of a bed or on a sofa, a soft warm mood', 'Une couverture épaisse pliée posée sur une chaise.', 'couverture blanket plaid couette chaud chambre'],
    ['oreillers', '1:1', 'Oreillers', 'Oreillers', 'Pillows', 'Pillows', 'bien gonflés sur un lit fait, lumière douce, sensation de confort', 'plump on a made bed, soft light, a feeling of comfort', 'Deux oreillers posés l’un sur l’autre sur un lit.', 'oreiller pillow coussin lit sommeil confort'],
    ['moustiquaires', '4:5', 'Moustiquaires', 'Moustiquaires', 'Mosquito nets', 'Mosquito nets', 'suspendue au-dessus d’un lit, voile léger et lumière douce, ambiance de nuit tranquille', 'hanging above a bed, light veil and soft light, a peaceful night mood', 'Une moustiquaire blanche pliée posée sur un lit.', 'moustiquaire mosquito net lit paludisme nuit protection'],
    ['protegematelas', '4:5', 'Protège-matelas', 'Protège-matelas', 'Mattress protectors', 'Protectors', 'sur un matelas propre, tissu bien tendu, ambiance de chambre soignée', 'on a clean mattress, fabric nicely stretched, a tidy bedroom mood', 'Un protège-matelas plié posé sur un lit.', 'protege matelas mattress protector alese lit hygiene'],
    ['lampechevet', '4:5', 'Lampes de chevet', 'Lampes', 'Bedside lamps', 'Lamps', 'allumée sur une table de chevet, lumière douce dans une chambre apaisante', 'on at a bedside table, soft light in a soothing bedroom', 'Une lampe de chevet éteinte posée sur une table de nuit.', 'lampe chevet bedside lamp lumiere chambre veilleuse'],
    ['tapisdescente', '1:1', 'Tapis de descente de lit', 'Descentes de lit', 'Bedside rugs', 'Bedside rugs', 'posé au pied d’un lit, sol clair, ambiance chaude de chambre', 'laid beside a bed, light floor, a warm bedroom mood', 'Un petit tapis moelleux posé au sol d’une chambre.', 'tapis descente de lit bedside rug chambre moelleux'],
  ],

  // ── Salle de bain ──
  bain: [
    ['serviettesbain', '4:5', 'Serviettes de bain', 'Serviettes', 'Bath towels', 'Towels', 'pliées en pile sur un tabouret de salle de bain, tons doux, ambiance de spa', 'folded in a stack on a bathroom stool, soft tones, a spa mood', 'Trois serviettes de bain pliées posées sur un lit.', 'serviette bain towel eponge toilette douche'],
    ['gantstoilette', '1:1', 'Gants de toilette', 'Gants', 'Washcloths', 'Washcloths', 'roulés dans un panier sur le bord d’une baignoire, ambiance douce et propre', 'rolled in a basket on the edge of a bathtub, a soft clean mood', 'Quatre gants de toilette colorés posés sur une table.', 'gant toilette washcloth lavette bain hygiene'],
    ['portesavon', '1:1', 'Porte-savons', 'Porte-savons', 'Soap dishes', 'Soap dishes', 'avec un savon posé dessus, au bord d’un lavabo propre, lumière claire', 'with a soap on top, on the edge of a clean sink, bright light', 'Un porte-savon en céramique vide posé sur un lavabo.', 'porte savon soap dish lavabo salle de bain'],
    ['portebrosses', '1:1', 'Porte-brosses à dents', 'Brosses à dents', 'Toothbrush holders', 'Toothbrushes', 'avec deux brosses à dents, posé sur un lavabo propre, lumière fraîche', 'with two toothbrushes, on a clean sink, fresh light', 'Un support pour brosses à dents posé sur un lavabo.', 'porte brosse dent toothbrush holder dentifrice lavabo'],
    ['rideaudouche', '4:5', 'Rideaux de douche', 'Rideaux', 'Shower curtains', 'Curtains', 'tiré devant une douche, motif net, salle de bain claire et propre', 'drawn in front of a shower, a crisp pattern, a bright clean bathroom', 'Un rideau de douche plié posé sur le bord d’une baignoire.', 'rideau douche shower curtain salle de bain'],
    ['tapisbain', '1:1', 'Tapis de bain', 'Tapis de bain', 'Bath mats', 'Bath mats', 'posé devant une baignoire sur un sol clair, tissu moelleux et propre', 'laid in front of a bathtub on a light floor, soft clean fabric', 'Un tapis de bain moelleux posé sur le carrelage.', 'tapis bain bath mat salle de bain antiderapant'],
    ['gobeletsbain', '1:1', 'Gobelets', 'Gobelets', 'Cups', 'Cups', 'posés près d’un lavabo avec des brosses à dents, ambiance simple et propre', 'placed near a sink with toothbrushes, a simple clean mood', 'Deux gobelets en plastique posés sur un lavabo.', 'gobelet tumbler verre cup plastique lavabo'],
    ['distributeursavon', '4:5', 'Distributeurs de savon', 'Distributeurs', 'Soap dispensers', 'Dispensers', 'posé sur un lavabo, avec une goutte de savon visible, lumière fraîche', 'on a sink, with a drop of soap visible, fresh light', 'Un distributeur de savon liquide vide posé sur un lavabo.', 'distributeur savon liquide soap dispenser pompe lavabo'],
  ],

  // ── Ménage et entretien ──
  menage: [
    ['serpilleres', '4:5', 'Serpillières', 'Serpillières', 'Floor cloths', 'Floor cloths', 'posée près d’un seau sur un sol propre et brillant, lumière claire', 'placed near a bucket on a clean shiny floor, bright light', 'Une serpillière en microfibre posée sur un sol.', 'serpilliere mop floor cloth sol nettoyage menage balai'],
    ['brossesnettoyage', '1:1', 'Brosses de nettoyage', 'Brosses', 'Cleaning brushes', 'Brushes', 'sur une surface propre et brillante, mousse légère autour, ambiance fraîche', 'on a clean shiny surface, light foam around, a fresh mood', 'Trois brosses de nettoyage de tailles différentes posées sur une table.', 'brosse nettoyage brush frotter menage toilettes'],
    ['eponges', '1:1', 'Éponges', 'Éponges', 'Sponges', 'Sponges', 'près d’un évier, mousse de savon et vaisselle propre, couleurs vives', 'near a sink, soap foam and clean dishes, bright colors', 'Un lot d’éponges colorées posées sur un évier.', 'eponge sponge vaisselle lavage menage mousse'],
    ['chiffons', '1:1', 'Chiffons', 'Chiffons', 'Cleaning cloths', 'Cloths', 'pliés en pile sur une surface propre, tissus doux et colorés', 'folded in a stack on a clean surface, soft colorful fabrics', 'Une pile de chiffons en microfibre posée sur une table.', 'chiffon cloth microfibre essuyage poussiere menage'],
    ['raclettesol', '4:5', 'Raclettes de sol', 'Raclettes', 'Floor squeegees', 'Squeegees', 'sur un sol carrelé propre, reflet net, ambiance de ménage efficace', 'on a clean tiled floor, crisp reflection, an efficient cleaning mood', 'Une raclette de sol appuyée contre un mur.', 'raclette sol squeegee balai carrelage menage eau'],
    ['gantsmenage', '1:1', 'Gants de ménage', 'Gants', 'Cleaning gloves', 'Gloves', 'jaunes posés sur le bord d’un évier, ambiance propre et vive', 'yellow ones resting on the edge of a sink, a clean lively mood', 'Une paire de gants de ménage jaunes posée sur un évier.', 'gant menage gloves caoutchouc vaisselle nettoyage'],
    ['panierdechets', '4:5', 'Paniers à déchets', 'Paniers à déchets', 'Waste baskets', 'Waste baskets', 'sous un bureau ou dans une chambre, modèle net et discret, lumière douce', 'under a desk or in a bedroom, a crisp discreet model, soft light', 'Une petite corbeille à papier posée à côté d’un bureau.', 'panier dechets corbeille poubelle waste basket bureau chambre'],
    ['bassines', '4:5', 'Bassines', 'Bassines', 'Basins', 'Basins', 'remplie d’eau et de linge à laver dans une cour ensoleillée, ambiance du quotidien', 'filled with water and laundry in a sunny courtyard, an everyday mood', 'Une bassine en plastique posée sur le sol.', 'bassine basin cuvette lessive linge eau plastique'],
    ['seaux', '4:5', 'Seaux', 'Seaux', 'Buckets', 'Buckets', 'à côté d’une serpillière sur un sol propre, couleurs vives, lumière claire', 'beside a mop on a clean floor, bright colors, clear light', 'Un seau en plastique posé sur un sol carrelé.', 'seau bucket plastique eau menage lavage'],
    ['savonpain', '1:1', 'Savon', 'Savon', 'Soap', 'Soap', 'en pains posés sur une serviette, lumière douce, ambiance de propreté', 'as bars set on a towel, soft light, a feeling of cleanliness', 'Trois savons en pain posés sur une table.', 'savon soap pain lavage toilette marseille hygiene'],
    ['lessive', '4:5', 'Lessive', 'Lessive', 'Laundry detergent', 'Detergent', 'à côté d’un panier de linge propre, ambiance de fraîcheur, lumière lumineuse', 'next to a basket of clean laundry, a fresh mood, bright light', 'Un paquet de lessive en poudre sans marque posé sur une table.', 'lessive detergent poudre liquide linge lavage machine'],
    ['liquidevaisselle', '4:5', 'Liquide vaisselle', 'Vaisselle', 'Dish soap', 'Dish soap', 'près d’un évier avec de la mousse et de la vaisselle qui brille', 'near a sink with foam and shiny dishes', 'Un flacon de liquide vaisselle sans marque posé sur un évier.', 'liquide vaisselle dish soap detergent evier mousse'],
    ['eaudejavel', '4:5', 'Eau de Javel', 'Javel', 'Bleach', 'Bleach', 'sur une étagère de produits d’entretien, ambiance propre et nette, sans danger visible', 'on a shelf of cleaning products, a clean crisp mood, no visible hazard', 'Un flacon d’eau de Javel sans marque posé sur une étagère.', 'eau de javel bleach desinfectant nettoyage toilettes'],
    ['papierhygienique', '4:5', 'Papier hygiénique', 'Papier', 'Toilet paper', 'Toilet paper', 'en pile ou en rouleaux dans un panier, salle de bain claire, ambiance propre', 'stacked or as rolls in a basket, a bright bathroom, a clean mood', 'Un paquet de rouleaux de papier hygiénique posé sur une table.', 'papier hygienique toilet paper rouleau wc toilettes'],
    ['mouchoirs', '1:1', 'Mouchoirs', 'Mouchoirs', 'Tissues', 'Tissues', 'dans une boîte posée sur une table de chevet, ambiance douce et familiale', 'in a box set on a bedside table, a soft family mood', 'Une boîte de mouchoirs en papier posée sur une table.', 'mouchoir tissue kleenex papier boite nez'],
    ['sacspoubelle', '4:5', 'Sacs-poubelle', 'Sacs-poubelle', 'Trash bags', 'Trash bags', 'en rouleau près d’une poubelle propre, ambiance nette de cuisine', 'as a roll near a clean bin, a crisp kitchen mood', 'Un rouleau de sacs-poubelle noirs posé sur un plan de travail.', 'sac poubelle trash bag dechets rouleau ordures'],
    ['parfumsinterieur', '4:5', 'Parfums d’intérieur', 'Parfums', 'Home fragrances', 'Fragrances', 'diffuseur de parfum posé dans un salon avec des fleurs, ambiance apaisante', 'a fragrance diffuser in a living room with flowers, a soothing mood', 'Un diffuseur de parfum d’ambiance avec des bâtonnets, posé sur une table.', 'parfum interieur diffuseur home fragrance ambiance encens'],
    ['allumettes', '1:1', 'Allumettes', 'Allumettes', 'Matches', 'Matches', 'une boîte posée près d’une bougie allumée, lumière chaude du soir', 'a box set near a lit candle, warm evening light', 'Une boîte d’allumettes posée sur une table.', 'allumette matches feu bougie boite cuisine'],
    ['bougiesmaison', '4:5', 'Bougies', 'Bougies', 'Candles', 'Candles', 'allumées sur une table de salon le soir, flamme douce, ambiance chaleureuse', 'lit on a living room table in the evening, soft flame, a warm mood', 'Trois bougies blanches éteintes posées sur une table.', 'bougie candle flamme ambiance deco parfumee'],
  ],

  // ── Cadeaux et décoration de fête ──
  cadeaux: [
    ['arrangementsflo', '4:5', 'Arrangements floraux', 'Fleurs', 'Floral arrangements', 'Flowers', 'posé au centre d’une table de réception, lumière douce, ambiance élégante', 'set in the middle of a reception table, soft light, an elegant mood', 'Un arrangement de fleurs dans un vase posé sur une table.', 'arrangement floral bouquet fleurs composition mariage fete'],
    ['panierscadeaux', '4:5', 'Paniers-cadeaux', 'Paniers-cadeaux', 'Gift baskets', 'Gift baskets', 'garni de produits bien présentés, ruban et papier de soie, fond clair et festif', 'filled with neatly presented products, ribbon and tissue paper, a light festive background', 'Un panier en osier garni de quelques produits posé sur une table.', 'panier cadeau gift basket coffret panier garni offrir'],
    ['boitescadeaux', '1:1', 'Boîtes cadeaux', 'Boîtes cadeaux', 'Gift boxes', 'Gift boxes', 'fermées par un ruban, empilées sur une table de fête, couleurs assorties', 'tied with a ribbon, stacked on a party table, matching colors', 'Trois boîtes cadeaux fermées posées sur une table.', 'boite cadeau gift box coffret ruban emballage offrir'],
    ['decotable', '4:5', 'Décorations de table', 'Déco de table', 'Table decorations', 'Table decor', 'sur une table de fête dressée, assiettes, serviettes et bougies assorties', 'on a laid party table, matching plates, napkins and candles', 'Une table sans nappe avec des assiettes empilées.', 'decoration table deco fete reception mariage anniversaire'],
    ['decoanniversaire', '4:5', 'Décorations pour anniversaires', 'Anniversaire', 'Birthday decorations', 'Birthday', 'dans une salle de fête, ballons, guirlandes et banderole vide, ambiance joyeuse', 'in a party room, balloons, garlands and a blank banner, a joyful mood', 'Des ballons colorés et une guirlande posés sur une table.', 'decoration anniversaire ballon guirlande birthday party fete enfant'],
    ['decomariage', '4:5', 'Décorations pour mariages', 'Mariage', 'Wedding decorations', 'Wedding', 'sur une table d’honneur, fleurs blanches, bougies et tissu clair, ambiance romantique', 'on a head table, white flowers, candles and light fabric, a romantic mood', 'Des bougeoirs et du tissu blanc posés sur une table.', 'decoration mariage wedding fleurs table honneur salle ceremonie'],
    ['centrestable', '1:1', 'Centres de table', 'Centres de table', 'Centerpieces', 'Centerpieces', 'au milieu d’une longue table de réception, fleurs et bougies, lumière chaude', 'in the middle of a long reception table, flowers and candles, warm light', 'Un centre de table composé de fleurs posé sur une table ronde.', 'centre de table centerpiece fleurs bougies reception mariage'],
    ['arbresdeco', '4:5', 'Arbres décoratifs artificiels', 'Arbres déco', 'Artificial decorative trees', 'Trees', 'dans un coin de salon près d’une fenêtre, feuillage dense, lumière naturelle', 'in a corner of a living room near a window, dense foliage, natural light', 'Un petit arbre artificiel dans un pot posé dans un salon.', 'arbre artificiel plante decorative faux arbre salon noel'],
    ['fleurssechees', '4:5', 'Compositions de fleurs séchées', 'Fleurs séchées', 'Dried flower arrangements', 'Dried flowers', 'dans un vase en terre cuite posé sur une console, tons beiges et chauds', 'in a terracotta vase on a console, warm beige tones', 'Un bouquet de fleurs séchées posé sur une table.', 'fleurs sechees dried flowers composition bouquet seche boheme deco'],
  ],

  // ── Beauté et accessoires du quotidien ──
  beaute: [
    ['troussetoilette', '1:1', 'Trousses de toilette', 'Trousses', 'Toiletry bags', 'Toiletry bags', 'ouverte sur un lit, flacons et brosses rangés à l’intérieur, ambiance de voyage', 'open on a bed, bottles and brushes packed inside, a travel mood', 'Une trousse de toilette fermée posée sur un lit.', 'trousse toilette toiletry bag voyage pochette soin'],
    ['miroirsmain', '1:1', 'Miroirs', 'Miroirs', 'Mirrors', 'Mirrors', 'sur une coiffeuse avec des produits de beauté, reflet net, lumière douce', 'on a vanity with beauty products, crisp reflection, soft light', 'Un petit miroir à main posé sur une table.', 'miroir mirror poche coiffeuse maquillage glace'],
    ['peignesbrosses', '1:1', 'Peignes et brosses', 'Peignes', 'Combs and brushes', 'Combs', 'alignés sur une coiffeuse, cheveux lisses en arrière-plan flou, ambiance salon de coiffure', 'lined up on a vanity, smooth hair blurred in the background, a hair-salon mood', 'Un peigne et deux brosses à cheveux posés sur une table.', 'peigne brosse cheveux comb hairbrush coiffure demelant'],
    ['boitesbijoux', '1:1', 'Boîtes à bijoux', 'Boîtes à bijoux', 'Jewelry boxes', 'Jewelry boxes', 'ouverte sur une commode, bijoux délicats à l’intérieur, lumière douce et précieuse', 'open on a dresser, delicate jewelry inside, soft precious light', 'Une boîte à bijoux fermée posée sur une commode.', 'boite bijoux jewelry box ecrin coffret rangement'],
  ],
};

// ── Styles de décoration : on redécore la pièce de la photo (l'architecture reste identique) ──
// [slug, titre FR, titre EN, caractéristiques FR, caractéristiques EN]
const STYLES = [
  ['stylemoderne', 'Décoration moderne', 'Modern decor', 'lignes épurées, meubles simples aux angles nets, palette neutre avec un accent de couleur, matériaux lisses', 'clean lines, simple furniture with crisp angles, a neutral palette with one accent color, smooth materials'],
  ['styletraditionnel', 'Décoration traditionnelle', 'Traditional decor', 'meubles en bois foncé, tissus à motifs, tons chauds, cadres dorés et objets de famille', 'dark wood furniture, patterned fabrics, warm tones, gilded frames and family heirlooms'],
  ['stylecontemporain', 'Décoration contemporaine', 'Contemporary decor', 'mélange actuel de formes douces et de textures, grandes surfaces claires, éclairage d’ambiance', 'a current mix of soft shapes and textures, large light surfaces, mood lighting'],
  ['styleminimaliste', 'Décoration minimaliste', 'Minimalist decor', 'très peu d’objets, murs blancs, meubles bas, beaucoup d’espace libre et de lumière', 'very few objects, white walls, low furniture, lots of free space and light'],
  ['styleafricain', 'Décoration africaine', 'African decor', 'tissus wax, masques et sculptures en bois, paniers tressés, motifs géométriques et couleurs terre chaudes', 'wax fabrics, wooden masks and sculptures, woven baskets, geometric patterns and warm earth colors'],
  ['styleethnique', 'Décoration ethnique', 'Ethnic decor', 'tapis tissés, poufs en cuir, objets artisanaux de plusieurs cultures, couleurs riches et motifs variés', 'woven rugs, leather poufs, handmade objects from several cultures, rich colors and varied patterns'],
  ['styleboheme', 'Décoration bohème', 'Boho decor', 'macramé, plantes suspendues, coussins de couleurs, tapis superposés, lumière douce de guirlandes', 'macramé, hanging plants, colorful cushions, layered rugs, soft string-light glow'],
  ['stylerustique', 'Décoration rustique', 'Rustic decor', 'bois brut, poutres apparentes, pierre, fer forgé et textiles en lin, ambiance de maison de campagne', 'raw wood, exposed beams, stone, wrought iron and linen textiles, a country-house mood'],
  ['stylevintage', 'Décoration vintage', 'Vintage decor', 'meubles des années cinquante à soixante-dix, couleurs pastel, objets anciens et lampes rétro', 'fifties to seventies furniture, pastel colors, old objects and retro lamps'],
  ['styleindustriel', 'Décoration industrielle', 'Industrial decor', 'métal noir, briques apparentes, béton ciré, bois épais et suspensions de style usine', 'black metal, exposed brick, polished concrete, thick wood and factory-style pendant lights'],
  ['stylescandinave', 'Décoration scandinave', 'Scandinavian decor', 'bois clair, murs blancs, textiles doux, plantes vertes et lumière naturelle abondante', 'light wood, white walls, soft textiles, green plants and plenty of natural light'],
  ['styleclassique', 'Décoration classique', 'Classic decor', 'symétrie, moulures aux murs, fauteuils capitonnés, lustre et tons crème et bleu profond', 'symmetry, wall moldings, upholstered armchairs, a chandelier and cream and deep blue tones'],
  ['styleluxe', 'Décoration luxueuse', 'Luxurious decor', 'marbre, velours, touches dorées, lustre en cristal et grands miroirs, finition haut de gamme', 'marble, velvet, gold touches, a crystal chandelier and large mirrors, a high-end finish'],
  ['stylechic', 'Décoration chic et élégante', 'Chic and elegant decor', 'palette beige et blanc cassé, canapé raffiné, miroirs, belles lampes et petits détails soignés', 'a beige and off-white palette, a refined sofa, mirrors, beautiful lamps and neat little details'],
  ['styleromantique', 'Décoration romantique', 'Romantic decor', 'tons rose poudré et crème, rideaux légers, bougies, fleurs fraîches et textiles doux', 'powder pink and cream tones, light curtains, candles, fresh flowers and soft textiles'],
  ['stylenaturel', 'Décoration naturelle', 'Natural decor', 'matières brutes, bois, rotin, lin et pierre, nombreuses plantes et couleurs de la nature', 'raw materials, wood, rattan, linen and stone, many plants and nature-inspired colors'],
  ['styletropical', 'Décoration tropicale', 'Tropical decor', 'grandes feuilles de palmier, rotin, tissus à motifs de feuillage, touches de vert vif et de jaune', 'large palm leaves, rattan, foliage-print fabrics, touches of bright green and yellow'],
  ['stylemediterraneen', 'Décoration méditerranéenne', 'Mediterranean decor', 'murs blancs, bleu azur, terre cuite, arches, tissus de lin et lumière chaude de soleil', 'white walls, azure blue, terracotta, arches, linen fabrics and warm sunlight'],
  ['stylejaponais', 'Décoration japonaise', 'Japanese decor', 'meubles bas, tatami, panneaux coulissants, bois clair, bambou et grande sobriété', 'low furniture, tatami, sliding panels, light wood, bamboo and great restraint'],
  ['styleoriental', 'Décoration orientale', 'Oriental decor', 'tapis aux motifs riches, coussins au sol, lanternes ciselées, tons bordeaux, or et bleu nuit', 'rich-patterned rugs, floor cushions, ornate lanterns, burgundy, gold and midnight blue tones'],
  ['styleprovencal', 'Décoration provençale', 'Provençal decor', 'bois patiné, tissus à fleurs, tons lavande et jaune doux, bouquets de lavande et poteries', 'weathered wood, floral fabrics, lavender and soft yellow tones, lavender bunches and pottery'],
  ['stylebaroque', 'Décoration baroque', 'Baroque decor', 'ornements dorés, velours profond, grands miroirs sculptés, lustres et meubles aux courbes riches', 'gilded ornaments, deep velvet, large carved mirrors, chandeliers and richly curved furniture'],
  ['styleartistique', 'Décoration artistique', 'Artistic decor', 'murs couverts de tableaux et d’affiches, sculptures, couleurs audacieuses et objets uniques', 'walls covered with paintings and posters, sculptures, bold colors and unique objects'],
  ['styleecologique', 'Décoration écologique', 'Eco-friendly decor', 'meubles de récupération, matériaux recyclés, bois certifié, plantes et lumière naturelle', 'upcycled furniture, recycled materials, certified wood, plants and natural light'],
  ['stylejapandi', 'Décoration minimaliste japonaise (Japandi)', 'Japanese minimalist decor (Japandi)', 'mélange de sobriété japonaise et de chaleur scandinave, bois clair et foncé, tons sable, lignes simples', 'a blend of Japanese restraint and Scandinavian warmth, light and dark wood, sand tones, simple lines'],
  ['stylecampagnechic', 'Décoration campagne chic', 'Chic country decor', 'bois clair patiné, textiles en lin blancs, fleurs des champs, touches dorées et fauteuils confortables', 'weathered light wood, white linen textiles, wildflowers, gold touches and comfortable armchairs'],
  ['stylevintageindus', 'Décoration vintage industrielle', 'Vintage industrial decor', 'métal patiné, cuir vieilli, caisses en bois, ampoules à filament et objets anciens récupérés', 'aged metal, worn leather, wooden crates, filament bulbs and salvaged old objects'],
  ['stylefuturiste', 'Décoration futuriste', 'Futuristic decor', 'formes arrondies blanches, éclairage LED de couleur, surfaces brillantes et meubles aérodynamiques', 'rounded white shapes, colored LED lighting, glossy surfaces and streamlined furniture'],
  ['styleglamour', 'Décoration glamour', 'Glamour decor', 'velours rose et doré, miroirs, paillettes discrètes, éclairage doux et coiffeuse de star', 'pink and gold velvet, mirrors, subtle sparkle, soft lighting and a star-style vanity'],
  ['stylerustiquemoderne', 'Décoration rustique moderne', 'Modern rustic decor', 'bois brut associé à des lignes épurées, métal noir, grandes baies vitrées et tons neutres', 'raw wood combined with clean lines, black metal, large windows and neutral tones'],
  ['styleafrocontemporain', 'Décoration afro-contemporaine', 'Afro-contemporary decor', 'meubles modernes aux lignes simples, touches de wax et de bois sculpté, art africain et couleurs chaudes', 'modern furniture with simple lines, touches of wax fabric and carved wood, African art and warm colors'],
  ['stylefestif', 'Décoration festive', 'Festive decor', 'ballons, guirlandes lumineuses, nappes colorées et confettis, ambiance de fête prête à accueillir', 'balloons, string lights, colorful tablecloths and confetti, a party mood ready to host guests'],
  ['styleevenementiel', 'Décoration événementielle', 'Event decor', 'salle dressée pour une réception : tables rondes, chaises habillées, arche de fleurs et éclairage d’ambiance', 'a room set for a reception: round tables, dressed chairs, a flower arch and mood lighting'],
  ['styleflorale', 'Décoration florale', 'Floral decor', 'bouquets frais partout, papiers peints à fleurs, vases de toutes tailles et couleurs de jardin', 'fresh bouquets everywhere, floral wallpaper, vases of all sizes and garden colors'],
  ['styleartisanal', 'Décoration artisanale', 'Handcrafted decor', 'objets faits main, paniers tressés, poteries, tissus brodés et bois sculpté, ambiance chaleureuse', 'handmade objects, woven baskets, pottery, embroidered fabrics and carved wood, a warm mood'],
  ['stylepersonnalise', 'Décoration personnalisée', 'Personalized decor', 'cadres photos de famille, objets gravés de prénoms, couleurs favorites et souvenirs mis en valeur', 'family photo frames, objects engraved with names, favorite colors and memories on display'],
];

// ── Composition des lignes (format de data_more.mjs) ──
const cap = (s) => s.charAt(0).toUpperCase() + s.slice(1);
const rows = {};
for (const [cat, list] of Object.entries(ITEMS)) {
  rows[cat] = list.map(([slug, ratio, ft, fp, et, ep, fc, ec]) => [
    slug, 'product', ratio, ft, fp,
    `${ft} : votre produit ${fc}, présenté comme dans un catalogue.`,
    `une photo publicitaire ${CAT[cat].fr} : le produit ${fc}, lumière douce et naturelle, rendu net et soigné de catalogue.`,
    et, ep,
    `${et}: your product ${ec}, presented like in a catalog.`,
    `an advertising photo for ${CAT[cat].en}: the product ${ec}, soft natural light, a crisp neat catalog look.`,
  ]);
}
rows.styles = STYLES.map(([slug, ft, et, ff, fe]) => [
  slug, 'place', '3:2', ft, cap(ft.replace(/^Décoration /, '')),
  `${ft} : redécorez la pièce de votre photo dans ce style. Meubles, couleurs et accessoires changent, la pièce reste la même.`,
  `une photo de la même pièce redécorée dans le style « ${ft.replace(/^Décoration /, '').toLowerCase()} » : ${ff}, lumière naturelle, rendu réaliste de magazine de décoration.`,
  et, cap(et.replace(/ decor$/i, '').replace(/ decor /i, ' ')),
  `${et}: redecorate the room in your photo in this style. Furniture, colors and accessories change, the room stays the same.`,
  `a photo of the same room redecorated in the “${et.replace(/ decor$/i, '').toLowerCase()}” style: ${fe}, natural light, a realistic decor-magazine look.`,
]);
export default rows;

// Mots de recherche (synonymes FR + EN, noms courants) : ajoutés au texte cherché de chaque commande
export const KW = {};
for (const list of Object.values(ITEMS)) for (const it of list) KW[it[0]] = it[9];
for (const [slug, ft, et] of STYLES) KW[slug] = `deco decoration style interieur salon chambre maison relooking home decor interior design ${et.toLowerCase()} ${ft.toLowerCase()}`;

// Mots de recherche ajoutés à des commandes DÉJÀ existantes qui répondent à des produits très cherchés (pas de doublon créé : on les rend simplement faciles à trouver)
Object.assign(KW, {
  hairaccessories: 'chouchou chouchous elastique pince barrette bandeau cheveux headband scrunchie',
  satinbonnet: 'bonnet de nuit bonnet satin nuit cheveux sleep cap',
  pouchset: 'trousse maquillage pochette trousse de toilette makeup bag pouch',
  walletkeys: 'portefeuille porte monnaie porte cles wallet',
  jewelwallet: 'portefeuille porte monnaie cuir wallet',
  jewelbag: 'sac a main handbag sac femme',
  sacvitrine: 'sac a main handbag sac femme',
  sacportee: 'sac a main handbag sac femme epaule',
  bagluxury: 'sac a main handbag luxe sac femme',
  pagnepouch: 'pochette pagne wax pouch',
  giftwrap: 'emballage cadeau papier cadeau ruban gift wrap carte',
  giftbox: 'coffret cadeau boite cadeau gift box',
  packcandle: 'bougie candle parfumee',
  packsoap: 'savon soap artisanal',
  homerug: 'tapis moquette rug carpet',
  homecurtains: 'rideau rideaux curtain voilage',
  homelinen: 'drap linge de maison serviette housse literie',
  homevase: 'vase fleurs flowers',
  homemirror: 'miroir mural mirror',
  homebath: 'salle de bain serviette tapis de bain accessoires',
});

// Photos de départ pour la génération des aperçus (comme celles de femmes.mjs : prise de vue banale, sans marque)
export const SRC = {};
for (const list of Object.values(ITEMS)) for (const it of list) SRC[it[0]] = it[8];
for (const [slug] of STYLES) SRC[slug] = 'Un salon simple et peu meublé, murs blancs, un canapé gris basique, une table basse et une fenêtre, photo prise au smartphone depuis un coin de la pièce.';

// Ordre de génération des aperçus (à lancer après recharge du compte) : ce que les clientes cherchent le plus d’abord
export const PRIORITY = {
  1: ['tapissalon', 'nappestable', 'housescoussins', 'vasesdeco', 'drapslit', 'taiesoreiller', 'serviettesbain', 'couverts', 'plateauservice', 'panierrangement',
    'savonpain', 'lessive', 'bougiesmaison', 'miroirsmain', 'troussetoilette', 'panierscadeaux', 'boitescadeaux', 'decoanniversaire', 'decomariage', 'stylemoderne',
    'styleafricain', 'styleboheme', 'styleluxe', 'styleminimaliste'],
  2: ['fleursartificielles', 'tableauxmuraux', 'horlogesmurales', 'guirlandeslumineuses', 'desodorisantsmaison', 'dessuslit', 'housesfauteuils', 'louches', 'couteauxcuisine', 'spatules',
    'passoires', 'bolscuisine', 'tassesverres', 'planchesdecouper', 'recipientsalim', 'bouteillesdeau', 'thermosisotherme', 'boitesepices', 'egouttoirs', 'corbeillepain',
    'saladiers', 'bolsfruits', 'potseau', 'carafes', 'setsdetable', 'dessousplat', 'dessousverre', 'serviettestable', 'boiterangement', 'organisateurtiroir',
    'rangechaussures', 'portevetements', 'cintres', 'panierlinge', 'poubelles', 'etageres', 'organisateurmaquillage', 'portebijoux', 'rangesacs', 'couvertures',
    'oreillers', 'moustiquaires', 'protegematelas', 'lampechevet', 'tapisdescente', 'gantstoilette', 'portesavon', 'portebrosses', 'rideaudouche', 'tapisbain',
    'gobeletsbain', 'distributeursavon', 'arrangementsflo', 'decotable', 'centrestable', 'arbresdeco', 'fleurssechees', 'peignesbrosses', 'boitesbijoux'],
  3: ['serpilleres', 'brossesnettoyage', 'eponges', 'chiffons', 'raclettesol', 'gantsmenage', 'panierdechets', 'bassines', 'seaux', 'liquidevaisselle',
    'eaudejavel', 'papierhygienique', 'mouchoirs', 'sacspoubelle', 'parfumsinterieur', 'allumettes'],
  styles: STYLES.map((s) => s[0]).filter((s) => !['stylemoderne', 'styleafricain', 'styleboheme', 'styleluxe', 'styleminimaliste'].includes(s)),
};

// Catégories nouvelles (id → catégorie de rangement de ce fichier) : utile aux scripts et à la vérification
export const NEW_CATEGORIES = ['decoint', 'cuisine', 'rangement', 'literie', 'bain', 'menage', 'cadeaux', 'styles'];
