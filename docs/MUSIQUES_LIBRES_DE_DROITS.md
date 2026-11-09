# Musiques libres de droits pour les modèles (proposition du 09/11/2026)

> **Rien n'est encore intégré à l'application** (les 64 morceaux sans voix et les 38 morceaux avec voix ont été téléchargés le 09/11/2026 depuis incompetech.com, avec l'accord du propriétaire, dans un dossier de travail hors du dépôt : 102 MP3 valides, environ 700 Mo bruts à 256 kbps ou plus, à compresser avant toute intégration). Cette liste est une réserve de **64 morceaux instrumentaux (sans voix) puis 38 morceaux avec voix** choisis pour illustrer les modèles
> (courage, amour, tristesse, persévérance, joie, calme, tension, humour, danse, américain, français…). Pour les ajouter à l'application il faut ton accord (téléchargement de
> 64 fichiers MP3, environ 3 à 6 Mo chacun, environ 250 Mo au total avant compression) et une écoute de chaque morceau.

## Source et licence (vérifiées le 09/11/2026)

- **Source retenue : incompetech.com, Kevin MacLeod.** La liste ci-dessous vient du fichier de données du site lui-même (`pieces.json`, 1 443 morceaux, ambiances « feel », durées, instruments).
- **Licence : Creative Commons Attribution 4.0 (CC BY 4.0), gratuite, avec crédit obligatoire.** Formule donnée par le site (à remplacer par le titre réel) :
  `Titre — Kevin MacLeod (incompetech.com) · Licensed under Creative Commons: By Attribution 4.0 · https://creativecommons.org/licenses/by/4.0/`
- Le crédit doit être trouvable sans difficulté par quelqu'un qui cherche l'origine de la musique (un écran « Crédits » dans l'application suffit, comme pour un jeu vidéo).
- **Point à confirmer avant de publier :** la FAQ du site ne dit rien du cas « une application qui propose la musique à ses utilisateurs pour leurs vidéos ». Deux voies : (1) écrire à l'auteur ; (2) sa « Standard License », payante, pour les cas où le crédit est impossible. Ce n'est pas un avis juridique.
- **FreePD (CC0) est fermé** depuis 2025 : écarté. Les autres sources (OpenGameArt CC0, Musopen, Free Music Archive) demandent de vérifier la licence morceau par morceau : non retenues ici.
- Les morceaux « domaine public » (Satie, Saint-Saëns, Joplin, Beethoven, Pachelbel, Wagner) sont des **compositions** libres ; ce qu'on utilise est l'**enregistrement de Kevin MacLeod**, sous CC BY.
- Les morceaux **sans voix** sont dans la première liste ; les morceaux **avec voix** (le propriétaire les veut aussi, 09/11/2026) sont dans la seconde liste, plus bas. Seuls ont été écartés ceux de plus de 8 minutes et ceux qui ne correspondent à aucun modèle.

## Comment ils seraient intégrés

1. Télécharger les fichiers, écouter chacun, garder ceux qui conviennent (environ 50).
2. Les convertir comme les 17 musiques actuelles (boucle sans coupure, normalisation du volume) et les ranger dans le stockage `studio_music/`.
3. Les ajouter au catalogue (`montage_music.dart`, `kStudioTracks`) et à la liste d'un modèle (`kTemplateMusic`), avec le **crédit affiché** dans le sélecteur de musique et dans l'écran « Crédits ».
4. Chaque modèle garde plusieurs choix de musique ; la personne peut en changer ou retirer la musique.

## Les morceaux, par humeur

| Morceau | Durée | BPM | Ambiances (site) | Humeur | Modèles | Origine |
|---|---|---|---|---|---|---|
| Heroic Age | 1:37 | 129 | Epic, Action, Driving, Bright | Courage, triomphe | Du chaos au triomphe, Ma réussite, Je vise plus haut | — |
| Undaunted | 3:33 | 95 | Driving, Epic, Action, Intense | Courage, combat | Mon combat, Du courage, Je ne lâcherai pas | — |
| Americana | 3:22 | 104 | Epic, Uplifting | Fierté, grands espaces | Mon chemin, Ma réussite, Je vise plus haut | Américain |
| Egmont Overture Finale | 1:44 | 150 | Driving, Epic, Uplifting | Triomphe | Du chaos au triomphe, Renaissance | Beethoven (domaine public), enregistrement d’orchestre |
| Noble Race | 5:16 | — | Epic, Intense, Driving | Ambition, héroïsme | Je vise plus haut, Mon année : film | — |
| At Launch | 3:05 | 102 | Epic, Uplifting, Suspenseful | Départ, lancement | Inauguration, Nouveau départ, Version 2.0 | — |
| Pennsylvania Rose | 1:19 | 82 | Epic, Uplifting | Ouest américain | Americana, Mon chemin | Américain (western) |
| Motivator | 3:58 | 126 | Driving, Uplifting, Bright | Persévérance, motivation | Mes objectifs, Je progresse, Mes résolutions | — |
| Nonstop | 3:11 | 128 | Driving, Grooving, Uplifting | Persévérance, énergie | Mes objectifs, Premier jour de travail | — |
| Super Power Cool Dude | 3:56 | 110 | Action, Driving, Uplifting | Énergie, détermination | Version 2.0, Je me réinvente | — |
| Inspired | 4:46 | 120 | Uplifting, Calming, Bright | Inspiration, espoir | Après la nuit, la lumière, Mes résolutions | — |
| Carpe Diem | 4:55 | 96 | Bouncy, Bright, Uplifting | Envie de vivre | Ça donne envie de vivre, Libre | — |
| Despair and Triumph | 4:46 | 43 | Dark, Mysterious, Somber | De la douleur à la victoire | De la galère au triomphe, Mon chemin | — |
| Reawakening | 3:34 | 56 | Calming, Relaxed, Uplifting | Amour tendre | Pensée d’amour, Retrouvailles | — |
| What Is Love | 3:28 | 58 | Calming, Relaxed | Amour, doute | L’amour, le vrai, Saint-Valentin | — |
| Canon in D for Two Harps | 5:40 | 83 | Bright, Calming, Relaxed | Mariage, romance | Le grand jour, Mariage | Pachelbel (domaine public), harpes |
| Valse Gymnopedie | 3:12 | 77 | Grooving, Relaxed | Romance, élégance | Pensée d’amour, Fiancé(e) | Français (Erik Satie, domaine public) |
| Wagner Bridal Chorus | 2:19 | 60 | Epic, Uplifting | Mariage | Le grand jour, Invitation | Wagner (domaine public), orgue |
| Royal Coupling | 2:14 | 60 | Bright, Calming | Élégance, cérémonie | Baptême, Mariage | Style Ravel (français) |
| Heavy Heart | 4:57 | 110 | Dark, Somber, Mystical | Tristesse, espoir | Tout est noir, Mon combat, Je tourne la page | — |
| Colorless Aura | 2:38 | 50 | Mysterious, Somber | Tristesse profonde | Tout est noir, Solitude | — |
| Disquiet | 3:05 | 70 | Somber, Calming | Mélancolie | Solitude, Jour de pluie, Hommage | — |
| Lost Time | 3:47 | 55 | Somber, Dark | Perte, regret | Hommage à un proche, Mon combat | — |
| Danse Morialta | 3:56 | 70 | Calming, Relaxed, Somber, Uplifting | Mélancolie douce | Nostalgie, Je tourne la page | — |
| Anguish | 3:59 | 54 | Calming, Dark, Somber | Angoisse, contemplation | Nuit blanche, Fatigué(e) de faire semblant | — |
| Calmant | 3:24 | 58 | Relaxed, Somber | Apaisement | Besoin de respirer, Je ne réponds plus | Titre français |
| Evening | 3:06 | 101 | Bright, Calming, Relaxed | Souvenirs, soirée douce | Mon année : film, Retrouvailles | Esprit Debussy (français) |
| Morning | 2:33 | 60 | Bright, Calming, Relaxed | Nouveau jour | Après la nuit, la lumière, Renaissance | — |
| Avec Soin | 2:25 | 64 | Calming, Relaxed | Tendresse, soin | Ma famille, Hommage | Titre français |
| Carefree | 3:25 | 96 | Bouncy, Bright, Calming, Uplifting | Insouciance | Dimanche calme, Voyage, Joie pure | — |
| Montauk Point | 3:40 | 118 | Bright, Bouncy, Uplifting | Bonne humeur | Samedi, on sort, La vie est belle | Américain (guitare) |
| Beachfront Celebration | 3:07 | 120 | Bouncy, Bright, Grooving, Uplifting | Fête, plage | Soirée, Voyage, Fête de la musique | — |
| Disco con Tutti | 3:56 | 115 | Bouncy, Bright, Grooving, Uplifting | Fête, danse | Vendredi soir, Soirée, Anniversaire | — |
| Celebration | 4:38 | 115 | Grooving, Relaxed | Célébration | Anniversaire, Réussite, Baptême | — |
| Cheery Monday | 1:20 | 102 | Bouncy, Bright, Relaxed | Début de semaine joyeux | Premier jour de travail | — |
| Airship Serenity | 4:00 | 74 | Calming, Uplifting | Sérénité | Paix intérieure, Détente | — |
| Immersed | 4:09 | 64 | Calming, Mystical, Relaxed, Somber | Calme profond | Paix intérieure, Mon bilan | — |
| Continue Life | 1:54 | — | Relaxed, Calming, Uplifting | Continuer | Je me réinvente, Je progresse | — |
| Amazing Grace 2011 | 3:09 | 79 | Calming, Relaxed, Somber | Spiritualité, louange | Baptême, Hommage, Mon combat | Américain (gospel, domaine public) |
| Man Down | 3:19 | 53 | Suspenseful, Dark, Somber | Chute, tension | Les temps sont durs, POV | — |
| Dark Fog | 3:59 | 71 | Dark, Grooving, Intense, Somber | Nuit, pensées sombres | Nuit blanche, Fatigué(e) de faire semblant | — |
| Mystery Bazaar | 2:38 | 75 | Calming, Dark, Mysterious | Mystère | Pensée de nuit, POV | — |
| Monkeys Spinning Monkeys | 2:05 | 144 | Bouncy, Bright, Humorous, Uplifting | Drôle, léger | Moi vs la réalité, Selfie raté | — |
| Sergio's Magic Dustbin | 2:31 | 204 | Bouncy, Driving, Humorous | Drôle, délire | Le wifi qui coupe, Défi : ne ris pas | — |
| Happy Happy Game Show | 2:39 | 230 | Grooving, Bouncy, Humorous | Jeu, humour | Note du jour, Défi : ne ris pas | Américain (blues 12 mesures) |
| Mischief Maker | 3:22 | 125 | Bouncy, Driving, Humorous | Malice | Quand maman appelle, Le régime | — |
| DarxieLand | 2:26 | 165 | Bouncy, Humorous, Bright | Drôle, jazz de La Nouvelle-Orléans | Avant / après le salaire, Moi vs la réalité | Américain (Dixieland) |
| Allada | 3:43 | 100 | Bouncy, Bright, Grooving | Danse africaine | Soirée, Fête de la musique, Samedi | Rythme ouest-africain |
| Arroz Con Pollo | 2:42 | 200 | Grooving, Bouncy, Bright | Danse latine | Samedi, on sort, Vente flash | Cubain |
| Samba Isobel | 4:10 | 95 | Bright, Grooving, Relaxed | Samba, chaleur | Vendredi soir, Voyage | Brésilien |
| Paradise Found | 3:07 | 105 | Bright, Grooving, Bouncy | Îles, soleil | Voyage, Détente, Weekend | Caraïbes |
| Maccary Bay | 4:00 | 80 | Grooving, Relaxed | Reggae | Weekend, Détente | Reggae |
| The Entertainer | 3:13 | 184 | Bright, Bouncy | Ragtime, rire | Moi vs la réalité, Note du jour | Américain (Scott Joplin, domaine public) |
| Maple Leaf Rag | 2:59 | 200 | Bright, Bouncy | Ragtime, énergie | Défi : ne ris pas, Selfie raté | Américain (Scott Joplin, domaine public) |
| Fireflies and Stardust | 4:15 | 170 | Bright, Calming, Relaxed | Campagne, douceur | Ma famille, Réunion de famille | Américain (americana, banjo) |
| Bama Country | 3:32 | 100 | Bouncy, Bright, Grooving | Country | Samedi, Réunion de famille | Américain (country) |
| Jazz Brunch | 5:23 | 100 | Bright, Grooving, Relaxed | Brunch, détente | Dimanche calme, Weekend | Jazz |
| Apero Hour | 4:43 | 140 | Bright, Grooving, Relaxed | Apéro, soirée | Vendredi soir, Inauguration | Titre français, jazz |
| Aquarium | 2:24 | 130 | Mysterious, Mystical, Bright | Rêverie | Retrouvailles, Mon année : film | Français (Saint-Saëns, domaine public) |
| Danse Macabre | 6:46 | 67 | Epic, Intense, Mysterious | Halloween, suspense | Halloween, POV | Français (Saint-Saëns, domaine public) |
| Late Night Radio | 4:24 | 72 | Calming, Relaxed | Nuit calme | Nuit blanche, Pensée de nuit | — |
| Backbay Lounge | 4:27 | 120 | Bright, Grooving, Relaxed | Lounge | Dimanche calme, Weekend | — |
| Adeste Fideles Waltz | 2:20 | 105 | Relaxed, Calming, Grooving | Boîte à musique, tendresse | Notre bébé arrive, Noël | Domaine public, boîte à musique |
| Dreamer | 3:24 | 100 | Calming, Relaxed | Rêve, famille | Notre bébé arrive, Ma famille | — |

Fichier source de chaque morceau : le titre suivi de « .mp3 » sur le site (exemple : « Heroic Age.mp3 »).

## Musiques AVEC VOIX (ajout du 09/11/2026 : le propriétaire veut des morceaux avec et sans voix)

> Précision du propriétaire : les morceaux **avec voix sont un plus**, pas à exclure. Voici 38 morceaux du même catalogue (CC BY 4.0, même crédit). **Limite honnête :** chez Kevin MacLeod
> la « voix » est presque toujours un **chœur ou des voix sans paroles** (pads, « aah », chants rituels) ; il y a très peu de vraies chansons à paroles (Habanera de Bizet, quelques morceaux
> chantés). Pour de **vraies chansons à paroles, américaines ou françaises**, il faudra une autre source : Free Music Archive (licences CC à vérifier titre par titre), Pixabay Music (licence Pixabay,
> usage libre mais pas de bibliothèque redistribuée telle quelle), ou des artistes qui signent un accord (comme les « sons d'artistes » déjà dans l'application).

| Morceau | Durée | BPM | Ambiances (site) | Humeur | Modèles | Voix |
|---|---|---|---|---|---|---|
| Magistar | 03:12 | 79 | Driving, Epic, Mystical | Courage, grandeur | Du chaos au triomphe, Je vise plus haut | Chœur |
| Our Story Begins | 01:25 | 129 | Epic, Suspenseful, Uplifting | Début d'histoire, élan | Mon année : film, Nouveau départ | Chœur |
| Long Road Ahead | 02:26 | 74 | Epic, Mystical, Somber | Long chemin, détermination | Mon chemin, Je ne lâcherai pas | Chœur |
| Truth of the Legend | 01:33 | 132 | Action, Dark, Driving, Epic, Intense | Légende, puissance | Ma réussite, Mon combat | Chœur |
| Winner Winner! | 03:18 | 200 | Bouncy, Bright, Humorous, Uplifting | Victoire joyeuse | Ma réussite, Anniversaire, Jeu concours | Chœur |
| AngloZulu | 01:05 | 108 | Driving, Epic, Grooving | Fierté africaine | Mon chemin, Inauguration | Chœur (style zoulou) |
| Reign | 02:43 | — | Calming, Epic, Somber, Uplifting | Triomphe calme | Ma réussite, Du chaos au triomphe | Chœur |
| Eternal Hope | 04:44 | — | Calming, Uplifting, Relaxed | Espoir | Après la nuit, la lumière, Je tourne la page | Chœur |
| Angel Share | 03:21 | 85 | Bright, Relaxed, Uplifting | Lumière, douceur | Renaissance, Notre bébé arrive | Chœur |
| Frozen Star | 03:41 | 88 | Calming, Mystical, Relaxed, Uplifting | Rêve, magie | Pensée d'amour, Nouvel an | Chœur |
| Skye Cuillin | 03:13 | 68 | Calming, Epic, Mystical, Uplifting | Grands espaces, émotion | Mon chemin, Voyage | Chœur |
| Aretes | 04:36 | 57 | Calming, Uplifting | Élévation, piano | Mes résolutions, Mon bilan | Chœur |
| Autumn Day | 03:05 | 126 | Bright, Calming | Jour tranquille, bonheur | Dimanche calme, Ma famille | Chœur |
| Adding the Sun | 02:56 | 90 | Calming, Grooving, Uplifting | Soleil, énergie douce | La vie est belle, Weekend | Chœur |
| Super Friendly | 02:14 | 108 | Bouncy, Bright, Uplifting | Bonne humeur, amitié | Retrouvailles, Samedi | Chœur |
| Bittersweet | 03:22 | 73 | Calming, Relaxed, Somber | Doux-amer | Je tourne la page, Nostalgie | Chœur |
| At Rest | 03:27 | 57 | Relaxed, Somber | Repos, hommage | Hommage à un proche, Solitude | Voix et chœur |
| Heart of Nowhere | 02:52 | 47 | Calming, Mystical, Somber | Vide, tristesse | Tout est noir, Solitude | Chœur |
| Quinn's Song: A New Man | 01:45 | 55 | Dark, Mysterious, Somber | Changement, gravité | Je me réinvente, Version 2.0 | Chœur |
| Night Vigil | 04:48 | 54 | Mystical, Somber | Veillée, recueillement | Hommage à un proche, Nuit blanche | Chœur |
| Shores of Avalon | 03:56 | — | Calming, Mysterious, Mystical, Somber | Mélancolie, rêverie | Pensée de nuit, Solitude | Voix solo |
| Send for the Horses | 03:05 | 70 | Dark, Mystical, Somber | Mélancolie sombre, chanteur | Tout est noir, Mon combat | Chanteur |
| Gregorian Chant | 03:14 | — | Mystical, Somber | Spirituel, recueillement | Baptême, Hommage | Chant grégorien |
| Virtutes Vocis | 04:19 | 56 | Calming, Mystical, Somber, Uplifting | Spirituel, voix pure | Baptême, Paix intérieure | Voix |
| Zanzibar | 03:39 | 105 | Mystical, Bouncy, Grooving | Danse africaine | Fête de la musique, Soirée | Chœur |
| Savannah (Sketch) | 03:24 | 82 | Grooving, Relaxed, Uplifting | Chaleur, Afrique | Voyage, Weekend | Chœur |
| Tafi Maradi | 02:39 | 133 | Bouncy, Grooving, Uplifting | Danse, joie africaine | Soirée, Anniversaire | Voix |
| Bumba Crossing | 04:37 | 92 | Bright, Calming | Insouciance tropicale | Voyage, Détente | Chœur |
| AhDah | 02:52 | 135 | Grooving, Relaxed | Groove, bonne humeur | Vendredi soir, Samedi | Voix |
| Zazie | 03:33 | 90 | Bouncy, Bright, Relaxed | Malice, joie | Moi vs la réalité, Quand maman appelle | Voix |
| Habanera | 04:08 | 110 | Bright, Epic | Passion, danse (opéra français) | L'amour, le vrai, Saint-Valentin, Soirée | Chanteuse solo (Carmen, Bizet, domaine public) |
| Bummin on Tremelo | 03:12 | 120 | Grooving, Relaxed, Bright | Blues américain, détente | Dimanche calme, Vendredi soir | Chanteurs |
| Porch Swing Days - slower | 03:36 | 110 | Bright, Calming, Relaxed, Uplifting | Americana, nostalgie | Ma famille, Réunion de famille | Voix |
| Porch Swing Days - faster | 03:05 | 130 | Bright, Calming, Relaxed, Uplifting | Americana, bonne humeur | Samedi, Réunion de famille | Voix |
| Greko (Sketch) | 03:35 | 72 | Bright, Driving, Grooving, Intense | Méditerranée, énergie | Voyage, Soirée | Voix |
| Ether Vox | 03:26 | 60 | Calming, Mystical, Relaxed | Calme, rêverie | Paix intérieure, Pensée de nuit | Voix |
| Future Cha Cha | 04:38 | 140 | Bouncy, Driving | Fête, danse | Anniversaire, Soirée | Voix |
| Graveyard Shift | 03:17 | 140 | Dark, Grooving, Humorous | Halloween, humour noir | Halloween | Chœur |
