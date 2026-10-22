# Suivi génération images de couverture — SlashAtlas
> 130 commandes sans image sur 944 — mise à jour manuelle à chaque session (dont 130 ajoutées le 22/10 : voir « À faire après recharge du compte »)

Chaque commande nécessite : `static/img/c/{slug}-t.webp` + `{slug}-apres.webp`
Une fois les deux fichiers présents, build.mjs retire automatiquement `noImage`.

---

## ⏳ À FAIRE APRÈS RECHARGE DU COMPTE — 130 commandes ajoutées le 22 octobre 2026

Produits du quotidien (maison, cuisine, linge, rangement, salle de bain, ménage, cadeaux, accessoires) et styles de décoration : ce que la plupart des clientes utilisent souvent. Elles sont **déjà sur le site, classées et trouvables par la recherche**, avec l’**aperçu d’attente** du site (catégorie + nom + code). Les vrais aperçus (photo de départ + résultat) restent à générer :

1. Recharger le compte de génération d’images.
2. Générer, dans cet ordre (P1 → P2 → P3 → styles) : `GEMINI_API_KEY=… node scripts/genimages.mjs <dossier> <slug> [<slug>…]` (les photos de départ sont dans `src/cmds/foyer.mjs`, objet SRC).
3. Optimiser : `python3 scripts/optimize_images.py <dossier>` (crée `-apres.webp`, `-t.webp`, `-avant.webp`).
4. `node build.mjs` : `noImage` disparaît tout seul pour chaque commande dont les deux fichiers existent, puis déployer le site.
5. Cocher ci-dessous au fur et à mesure.

Ordre : P1 = 24 commandes, P2 = 59, P3 = 16, styles restants = 31.

### P1 — les plus utilisées (24)
- [ ] tapissalon — Tapis de salon (Décoration d’intérieur)
- [ ] nappestable — Nappes de table (Décoration d’intérieur)
- [ ] housescoussins — Housses de coussins (Décoration d’intérieur)
- [ ] vasesdeco — Vases décoratifs (Décoration d’intérieur)
- [ ] drapslit — Draps de lit (Literie & Linge de maison)
- [ ] taiesoreiller — Taies d’oreiller (Literie & Linge de maison)
- [ ] serviettesbain — Serviettes de bain (Salle de bain)
- [ ] couverts — Cuillères et fourchettes (Cuisine & Art de la table)
- [ ] plateauservice — Plateaux de service (Cuisine & Art de la table)
- [ ] panierrangement — Paniers de rangement (Rangement & Organisation)
- [ ] savonpain — Savon (Ménage & Entretien)
- [ ] lessive — Lessive (Ménage & Entretien)
- [ ] bougiesmaison — Bougies (Ménage & Entretien)
- [ ] miroirsmain — Miroirs (Beauté & Coiffure)
- [ ] troussetoilette — Trousses de toilette (Beauté & Coiffure)
- [ ] panierscadeaux — Paniers-cadeaux (Cadeaux & Déco de fête)
- [ ] boitescadeaux — Boîtes cadeaux (Cadeaux & Déco de fête)
- [ ] decoanniversaire — Décorations pour anniversaires (Cadeaux & Déco de fête)
- [ ] decomariage — Décorations pour mariages (Cadeaux & Déco de fête)
- [ ] stylemoderne — Décoration moderne (Styles de décoration)
- [ ] styleafricain — Décoration africaine (Styles de décoration)
- [ ] styleboheme — Décoration bohème (Styles de décoration)
- [ ] styleluxe — Décoration luxueuse (Styles de décoration)
- [ ] styleminimaliste — Décoration minimaliste (Styles de décoration)

### P2 (59)
- [ ] fleursartificielles — Fleurs artificielles (Décoration d’intérieur)
- [ ] tableauxmuraux — Tableaux muraux (Décoration d’intérieur)
- [ ] horlogesmurales — Horloges murales (Décoration d’intérieur)
- [ ] guirlandeslumineuses — Guirlandes lumineuses (Décoration d’intérieur)
- [ ] desodorisantsmaison — Désodorisants d’intérieur (Décoration d’intérieur)
- [ ] dessuslit — Dessus de lit (Décoration d’intérieur)
- [ ] housesfauteuils — Housses de fauteuils (Décoration d’intérieur)
- [ ] louches — Louches (Cuisine & Art de la table)
- [ ] couteauxcuisine — Couteaux de cuisine (Cuisine & Art de la table)
- [ ] spatules — Spatules (Cuisine & Art de la table)
- [ ] passoires — Passoires (Cuisine & Art de la table)
- [ ] bolscuisine — Bols (Cuisine & Art de la table)
- [ ] tassesverres — Tasses et verres (Cuisine & Art de la table)
- [ ] planchesdecouper — Planches à découper (Cuisine & Art de la table)
- [ ] recipientsalim — Récipients alimentaires (Cuisine & Art de la table)
- [ ] bouteillesdeau — Bouteilles d’eau (Cuisine & Art de la table)
- [ ] thermosisotherme — Thermos (Cuisine & Art de la table)
- [ ] boitesepices — Boîtes à épices (Cuisine & Art de la table)
- [ ] egouttoirs — Égouttoirs à vaisselle (Cuisine & Art de la table)
- [ ] corbeillepain — Corbeilles à pain (Cuisine & Art de la table)
- [ ] saladiers — Saladiers (Cuisine & Art de la table)
- [ ] bolsfruits — Bols à fruits (Cuisine & Art de la table)
- [ ] potseau — Pots à eau (Cuisine & Art de la table)
- [ ] carafes — Carafes (Cuisine & Art de la table)
- [ ] setsdetable — Sets de table (Cuisine & Art de la table)
- [ ] dessousplat — Dessous-de-plat (Cuisine & Art de la table)
- [ ] dessousverre — Dessous-de-verre (Cuisine & Art de la table)
- [ ] serviettestable — Serviettes de table (Cuisine & Art de la table)
- [ ] boiterangement — Boîtes de rangement (Rangement & Organisation)
- [ ] organisateurtiroir — Organisateurs de tiroirs (Rangement & Organisation)
- [ ] rangechaussures — Range-chaussures (Rangement & Organisation)
- [ ] portevetements — Porte-vêtements (Rangement & Organisation)
- [ ] cintres — Cintres (Rangement & Organisation)
- [ ] panierlinge — Paniers à linge (Rangement & Organisation)
- [ ] poubelles — Poubelles (Rangement & Organisation)
- [ ] etageres — Étagères (Rangement & Organisation)
- [ ] organisateurmaquillage — Organisateurs de maquillage (Rangement & Organisation)
- [ ] portebijoux — Porte-bijoux (Rangement & Organisation)
- [ ] rangesacs — Range-sacs (Rangement & Organisation)
- [ ] couvertures — Couvertures (Literie & Linge de maison)
- [ ] oreillers — Oreillers (Literie & Linge de maison)
- [ ] moustiquaires — Moustiquaires (Literie & Linge de maison)
- [ ] protegematelas — Protège-matelas (Literie & Linge de maison)
- [ ] lampechevet — Lampes de chevet (Literie & Linge de maison)
- [ ] tapisdescente — Tapis de descente de lit (Literie & Linge de maison)
- [ ] gantstoilette — Gants de toilette (Salle de bain)
- [ ] portesavon — Porte-savons (Salle de bain)
- [ ] portebrosses — Porte-brosses à dents (Salle de bain)
- [ ] rideaudouche — Rideaux de douche (Salle de bain)
- [ ] tapisbain — Tapis de bain (Salle de bain)
- [ ] gobeletsbain — Gobelets (Salle de bain)
- [ ] distributeursavon — Distributeurs de savon (Salle de bain)
- [ ] arrangementsflo — Arrangements floraux (Cadeaux & Déco de fête)
- [ ] decotable — Décorations de table (Cadeaux & Déco de fête)
- [ ] centrestable — Centres de table (Cadeaux & Déco de fête)
- [ ] arbresdeco — Arbres décoratifs artificiels (Cadeaux & Déco de fête)
- [ ] fleurssechees — Compositions de fleurs séchées (Cadeaux & Déco de fête)
- [ ] peignesbrosses — Peignes et brosses (Beauté & Coiffure)
- [ ] boitesbijoux — Boîtes à bijoux (Beauté & Coiffure)

### P3 (16)
- [ ] serpilleres — Serpillières (Ménage & Entretien)
- [ ] brossesnettoyage — Brosses de nettoyage (Ménage & Entretien)
- [ ] eponges — Éponges (Ménage & Entretien)
- [ ] chiffons — Chiffons (Ménage & Entretien)
- [ ] raclettesol — Raclettes de sol (Ménage & Entretien)
- [ ] gantsmenage — Gants de ménage (Ménage & Entretien)
- [ ] panierdechets — Paniers à déchets (Ménage & Entretien)
- [ ] bassines — Bassines (Ménage & Entretien)
- [ ] seaux — Seaux (Ménage & Entretien)
- [ ] liquidevaisselle — Liquide vaisselle (Ménage & Entretien)
- [ ] eaudejavel — Eau de Javel (Ménage & Entretien)
- [ ] papierhygienique — Papier hygiénique (Ménage & Entretien)
- [ ] mouchoirs — Mouchoirs (Ménage & Entretien)
- [ ] sacspoubelle — Sacs-poubelle (Ménage & Entretien)
- [ ] parfumsinterieur — Parfums d’intérieur (Ménage & Entretien)
- [ ] allumettes — Allumettes (Ménage & Entretien)

### Styles de décoration (suite) (31)
- [ ] styletraditionnel — Décoration traditionnelle (Styles de décoration)
- [ ] stylecontemporain — Décoration contemporaine (Styles de décoration)
- [ ] styleethnique — Décoration ethnique (Styles de décoration)
- [ ] stylerustique — Décoration rustique (Styles de décoration)
- [ ] stylevintage — Décoration vintage (Styles de décoration)
- [ ] styleindustriel — Décoration industrielle (Styles de décoration)
- [ ] stylescandinave — Décoration scandinave (Styles de décoration)
- [ ] styleclassique — Décoration classique (Styles de décoration)
- [ ] stylechic — Décoration chic et élégante (Styles de décoration)
- [ ] styleromantique — Décoration romantique (Styles de décoration)
- [ ] stylenaturel — Décoration naturelle (Styles de décoration)
- [ ] styletropical — Décoration tropicale (Styles de décoration)
- [ ] stylemediterraneen — Décoration méditerranéenne (Styles de décoration)
- [ ] stylejaponais — Décoration japonaise (Styles de décoration)
- [ ] styleoriental — Décoration orientale (Styles de décoration)
- [ ] styleprovencal — Décoration provençale (Styles de décoration)
- [ ] stylebaroque — Décoration baroque (Styles de décoration)
- [ ] styleartistique — Décoration artistique (Styles de décoration)
- [ ] styleecologique — Décoration écologique (Styles de décoration)
- [ ] stylejapandi — Décoration minimaliste japonaise (Japandi) (Styles de décoration)
- [ ] stylecampagnechic — Décoration campagne chic (Styles de décoration)
- [ ] stylevintageindus — Décoration vintage industrielle (Styles de décoration)
- [ ] stylefuturiste — Décoration futuriste (Styles de décoration)
- [ ] styleglamour — Décoration glamour (Styles de décoration)
- [ ] stylerustiquemoderne — Décoration rustique moderne (Styles de décoration)
- [ ] styleafrocontemporain — Décoration afro-contemporaine (Styles de décoration)
- [ ] stylefestif — Décoration festive (Styles de décoration)
- [ ] styleevenementiel — Décoration événementielle (Styles de décoration)
- [ ] styleflorale — Décoration florale (Styles de décoration)
- [ ] styleartisanal — Décoration artisanale (Styles de décoration)
- [ ] stylepersonnalise — Décoration personnalisée (Styles de décoration)

---


## Légende
- `[ ]` À faire
- `[→]` En cours
- `[x]` Terminé

---

## GROUPE 1 — Produits à vendre (priorité haute)

### ECOM (12) — E-commerce
- [x] shopflash — Vente flash / promo urgente
- [x] shopnew — Nouveaux arrivages
- [x] shopbundle — Pack / bundle produits
- [x] shopdelivery — Annonce livraison
- [x] shopapp — Application boutique
- [x] shopfintech — Paiement mobile / fintech
- [x] shopwhatsapp — Commande WhatsApp
- [x] shopcatalog — Catalogue produits
- [x] shopreview — Avis clients
- [x] shopdrop — Lancement exclusif / drop
- [x] shopbacksale — Soldes de fin de saison
- [x] shopinstagram — Shopping Instagram

### BUSINESS (24) — Entreprise & services
- [x] bizhiring — Recrutement / offre d'emploi
- [x] bizteam — Photo d'équipe
- [x] bizceo — Portrait dirigeant
- [x] bizlinkedin — Post LinkedIn
- [x] bizwebinar — Webinaire
- [x] bizoffice — Bureau / espace de travail
- [x] bizcoworking — Coworking
- [x] bizstartup — Startup / innovation
- [x] bizmeeting — Réunion / présentiel
- [x] bizcard — Carte de visite
- [x] bizlogoreveal — Révélation de logo
- [x] bizsale — Promotion commerciale
- [x] bizgrandopening — Grande ouverture
- [x] bizshop — Vitrine de boutique
- [x] bizdelivery — Service de livraison
- [x] bizfinance — Finance / comptabilité
- [x] bizlegal — Juridique / legal
- [x] bizconsult — Cabinet conseil
- [x] bizcatering — Traiteur / restauration pro
- [x] bizngo — ONG / association
- [x] bizcourier — Service courrier
- [x] bizcallcenter — Centre d'appel
- [x] bizanniversary — Anniversaire d'entreprise
- [x] bizpodcast — Podcast professionnel

---

## GROUPE 2 — Services (priorité moyenne-haute)

### VOYAGE (24)
- [x] travelhotel — Hôtel
- [x] travelroom — Chambre d'hôtel
- [x] travelpool — Piscine / resort
- [x] travelbeach — Plage
- [x] travelsafari — Safari
- [x] travelcity — City break / ville
- [x] travelflight — Billet d'avion
- [x] travelsuitcase — Valise / préparation voyage
- [x] travelpackage — Package séjour
- [x] travelrestaurant — Restaurant en voyage
- [x] travelcouple — Voyage en couple
- [x] travelfamily — Voyage en famille
- [x] traveltour — Circuit guidé
- [x] travelmountain — Montagne / randonnée
- [x] travelcar — Location de voiture
- [x] travelcruise — Croisière
- [x] travelcamp — Camping / glamping
- [x] travelvilla — Villa de vacances
- [x] travelculture — Tourisme culturel
- [x] travelbooking — Réservation en ligne
- [x] travelpromo — Promo voyage
- [x] travelairbnb — Hébergement Airbnb
- [x] travelstreetfood — Street food locale
- [x] travelvisa — Visa / démarches

### SANTE (24)
- [x] healthclinic — Clinique / cabinet médical
- [x] healthdoctor — Médecin / consultation
- [x] healthdental — Dentiste
- [x] healthpharmacy — Pharmacie
- [x] healthyoga — Yoga
- [x] healthgym — Salle de sport
- [x] healthnutrition — Nutrition / diététique
- [x] healthjuice — Jus & smoothies santé
- [x] healthherbal — Plantes médicinales
- [x] healthvitamin — Compléments alimentaires
- [x] healthmassage — Massage thérapeutique
- [x] healthspa — Spa médical
- [x] healthmeditate — Méditation
- [x] healthsleep — Sommeil / bien dormir
- [x] healthrun — Course / running santé
- [x] healthhydrate — Hydratation
- [x] healthcheckup — Bilan de santé
- [x] healthmother — Maternité / grossesse
- [x] healthelder — Personnes âgées / séniors
- [x] healthcampaign — Campagne de santé publique
- [x] healthhands — Hygiène des mains
- [x] healthsportwear — Tenue de sport santé
- [x] healthcoach — Coach santé
- [x] healthorganic — Bio / naturel

### EDUCATION (24)
- [x] educourse — Cours en ligne
- [x] eduworkshop — Atelier / workshop
- [x] eduwebinar — Webinaire éducatif
- [x] edubackschool — Rentrée scolaire
- [x] eduenroll — Inscription / candidature
- [x] eduprofessional — Formation professionnelle
- [x] educoach — Coaching / mentorat
- [x] edulanguage — Apprentissage de langue
- [x] edutech — Formation tech / coding
- [x] edusewing — Couture / broderie
- [x] educooking — Cours de cuisine
- [x] edumusic — Cours de musique
- [x] eduschool — École primaire / secondaire
- [x] eduuniversity — Université
- [x] edulibrary — Bibliothèque
- [x] eduonline — Plateforme e-learning
- [x] educertificate — Certification / diplôme
- [x] edukids — Enfants / pédagogie
- [x] eduhomework — Devoirs / révisions
- [x] eduexam — Examens
- [x] edubootcamp — Bootcamp intensif
- [x] edumentor — Mentor / tuteur
- [x] educonference — Conférence académique
- [x] eduscholarship — Bourse d'études

---

## GROUPE 3 — Contenu créatif (priorité moyenne)

### MUSIQUE (21)
- [NOGEN] djnight — Soirée DJ (refus modèle)
- [x] rapcover — Pochette rap
- [x] afrobeatsun — Afrobeat / soleil
- [x] gospelchoir — Chorale gospel
- [x] singlepastel — Single pastel / pop
- [x] tourdates — Dates de tournée
- [x] guitarportrait — Portrait guitariste
- [x] studiosession — Session studio
- [x] festivalstage — Scène de festival
- [x] vinylretro — Vinyle rétro
- [x] bandgroup — Groupe de musique
- [x] soulballad — Ballade soul
- [x] podcastcover — Couverture podcast
- [x] backstage — Backstage / coulisses
- [x] albumpreorder — Précommande album
- [x] drummerenergy — Batteur / énergie
- [x] pianoevening — Soirée piano
- [x] heritagemusic — Musique traditionnelle / patrimoine
- [x] dancefloorclip — Dancefloor / clip
- [x] radiohost — Animateur radio
- [x] musiclesson — Cours de musique

### EVENEMENT (22)
- [NOGEN] inauguration — Inauguration officielle (refus modèle)
- [NOGEN] conference — Conférence (refus modèle)
- [x] babyshower — Baby shower
- [x] graduationday — Remise de diplômes
- [x] worshipevent — Événement religieux
- [x] tributememory — Hommage / mémorial
- [x] galanight — Soirée gala
- [x] nightmarket — Marché nocturne
- [x] charityevent — Événement caritatif
- [x] fashionshow — Défilé de mode
- [x] expobooth — Stand expo / salon
- [x] workshopday — Journée atelier
- [x] weddingreception — Réception de mariage
- [x] engagementparty — Fête des fiançailles
- [x] culturalfestival — Festival culturel
- [x] launchparty — Soirée lancement produit
- [x] networkingdrinks — Afterwork / networking
- [x] shopanniversary — Anniversaire de boutique
- [x] seasongreetings — Vœux de saison
- [x] eidgreetings — Vœux de l'Aïd
- [x] schoolopenday — Journée portes ouvertes école
- [x] poolparty — Pool party

### RESEAUX (20)
- [x] tutorialthumb — Miniature tutoriel
- [x] feedgrid — Grille de feed Instagram
- [x] hookvertical — Hook vidéo vertical
- [x] proportrait — Portrait professionnel réseau
- [x] profilebanner — Bannière de profil
- [x] livepromo — Promo pour un live
- [x] giveawaypost — Post giveaway / concours
- [x] pollstory — Sondage story
- [x] launchcountdown — Compte à rebours lancement
- [x] customertestimonial — Témoignage client
- [x] teamintro — Présentation d'équipe
- [x] brandbts — Coulisses de marque (BTS)
- [x] stepsguide — Guide étapes
- [x] minimalcover — Couverture minimaliste
- [x] promocodecard — Carte code promo
- [x] hiringpost — Post recrutement
- [x] thankyoufollowers — Remerciement abonnés
- [x] quoteportrait — Citation avec portrait
- [x] eventreminder — Rappel d'événement
- [x] unboxingreview — Unboxing / review

---

## GROUPE 4 — Visuels & créatifs (priorité basse)

### TYPO (13)
- [x] typobehind — Texte derrière le sujet
- [x] typoslogan — Slogan
- [x] typoneon — Typographie néon
- [x] typoretro — Style rétro
- [x] typograffiti — Graffiti / street art
- [x] typoswiss — Style suisse / épuré
- [x] typogold — Texte doré
- [x] typoshadow — Ombre / shadow
- [x] typocollage — Collage typographique
- [x] typochrome — Duotone / chromatique
- [x] typobold2 — Gras / impact
- [x] typohandwritten — Manuscrit / handwritten
- [x] typocountdown — Compte à rebours typo

### LOGOMAT (12)
- [x] logoglass — Logo effet verre
- [x] logoice — Logo effet glace
- [x] logoclouds — Logo dans les nuages
- [x] logoembroidery — Logo brodé
- [x] logochrome — Logo chromé
- [NOGEN] logowood — Logo bois (refus NSFW)
- [x] logoballoon — Logo ballons
- [x] logoneonsign — Logo enseigne néon
- [x] logogold — Logo doré
- [x] logosand — Logo sable
- [x] logoflowers — Logo fleurs
- [x] logoneonglow — Logo néon lumineux

### PLANCHES (13)
- [x] sheetpose9 — 9 poses / grid 3×3
- [x] sheetexpress — Expressions multiples
- [x] sheetcolors — Variantes de couleur
- [x] sheetangles — Angles / vues multiples
- [x] sheetseasons — Saisons
- [x] sheetdaynight — Jour / nuit
- [x] sheetstyles — Styles différents
- [x] sheetmoods — Ambiances / moods
- [x] sheetbeforeafter — Avant / après côte à côte
- [x] sheetstory6 — Storyboard 6 cases
- [x] sheetportraitburst — Rafale de portraits
- [x] sheetcontact — Planche contact
- [x] sheetsteps3 — 3 étapes

### INFOGRAPHIE (13)
- [x] infoexploded — Vue éclatée produit
- [x] infoquad — 4 faits clés
- [x] infomap — Carte / itinéraire
- [x] infotravel4 — Infographie voyage 4 destinations
- [x] infofood — Infographie alimentaire
- [x] inforecipe — Recette illustrée
- [x] infoproduct — Fiche produit détaillée
- [x] infotimeline — Timeline / chronologie
- [x] infosteps — Étapes de processus
- [x] infocompare — Comparatif
- [x] infochart — Graphique / stats
- [x] infoanatomy — Anatomie produit
- [x] infoscience — Infographie scientifique

### JALONS (12)
- [x] milesnumber — Chiffre marquant
- [x] milesmonth — Mensuel (bébé / objectif)
- [x] milesbirth — Naissance
- [x] milesgraduation — Diplôme / promotion
- [x] milesbirthday — Anniversaire personnel
- [x] milesengagement — Fiançailles
- [x] milessavedate — Save the date
- [x] milesretire — Retraite
- [x] milesmemorial — Commémoration
- [x] milesnewyear — Nouvel an
- [x] milesfamilytree — Arbre généalogique
- [x] milesceremony — Cérémonie / remise

### ANIME (12)
- [x] animeposter — Affiche anime
- [x] animesilhouette — Silhouette anime
- [x] animeschool — Ambiance école anime
- [x] animechibi — Style chibi
- [x] animewatercolor — Aquarelle anime
- [x] animecrossstitch — Point de croix anime
- [x] animeline — Ligne claire anime
- [x] anime3d — Anime 3D
- [x] animecomicpop — Comic / pop art anime
- [x] animefantasy — Fantaisie / fantasy
- [x] animestorybook — Livre illustré
- [x] animebook8 — Manga 8 cases

### MARQUE (12)
- [x] brandboard — Moodboard de marque
- [x] brandlogo — Logo sur fond
- [x] brandcard — Carte de visite marque
- [x] brandmerch — Merchandising
- [x] brandapp — Interface app
- [x] brandsign — Signalétique
- [x] brandpackaging — Packaging de marque
- [x] brandsocial — Kit réseaux sociaux
- [x] brandbanner — Bannière de marque
- [x] brandmockuphero — Mockup hero
- [x] brandpresentation — Présentation de marque
- [x] brandcaps — Casquettes / textiles marqués

### MAGAZINE (12)
- [x] magcover — Une de magazine
- [x] magbusiness — Magazine business
- [x] magopen — Double page ouverte
- [x] magproduct — Page produit magazine
- [x] magbeauty — Magazine beauté
- [x] magsport — Magazine sport
- [x] magfood — Magazine food
- [x] magtravel — Magazine voyage
- [x] magestate — Magazine immobilier
- [x] magretro — Magazine rétro
- [x] magnewspaper — Style journal / presse
- [x] magrecord — Label / record magazine

### MASCOTTE (2)
- [x] mascotrocket — Mascotte fusée
- [NOGEN] mascotsticker2 — Sticker mascotte v2 (refus modèle)

### KIT (24) — kind:text — pas d'image possible
- [N/A] kithooks — Hooks d'accroche
- [N/A] kitscript15 — Script 15 secondes
- [N/A] kitscript30 — Script 30 secondes
- [N/A] kitstoryboard — Storyboard
- [N/A] kitvoiceover — Voix off
- [N/A] kitcaptions — Sous-titres
- [N/A] kithashtags — Hashtags optimisés
- [N/A] kitcal7 — Calendrier 7 jours
- [N/A] kitcal30 — Calendrier 30 jours
- [N/A] kitfaceless — Contenu sans visage
- [N/A] kitbio — Biographie profil
- [N/A] kitpinned — Post épinglé
- [N/A] kitthumbs — Miniatures YouTube
- [N/A] kitshorts — Shorts / Reels
- [N/A] kitoffer — Offre irrésistible
- [N/A] kitbroadcast — Canal broadcast
- [N/A] kitreplies — Réponses automatiques
- [N/A] kitdm — Messages directs DM
- [N/A] kitcarousel — Carrousel
- [N/A] kitseries — Série de contenus
- [N/A] kittrend — Tendance / trend
- [N/A] kitgiveaway — Giveaway / concours
- [N/A] kitlaunch — Lancement produit
- [N/A] kitshots — Shots de produits

### EFFETS (2)
- [NOGEN] cyberpunk — Style cyberpunk (refus modèle)
- [NOGEN] blueprint — Plan technique / blueprint (refus modèle)

---

## Résumé d'avancement

> Légende résumé : NOGEN = refus permanent du modèle, N/A = commande texte (pas d'image)

| Groupe | Catégorie | Total | Fait | NOGEN/N/A | Reste à générer |
|--------|-----------|-------|------|-----------|-----------------|
| 1 | ECOM | 12 | 12 | 0 | 0 |
| 1 | BUSINESS | 24 | 24 | 0 | 0 |
| 2 | VOYAGE | 24 | 24 | 0 | 0 |
| 2 | SANTE | 24 | 24 | 0 | 0 |
| 2 | EDUCATION | 24 | 24 | 0 | 0 |
| 3 | MUSIQUE | 21 | 20 | 1 (djnight) | 0 |
| 3 | EVENEMENT | 22 | 20 | 2 (inauguration, conference) | 0 |
| 3 | RESEAUX | 20 | 20 | 0 | 0 |
| 4 | TYPO | 13 | 13 | 0 | 0 |
| 4 | LOGOMAT | 12 | 11 | 1 (logowood) | 0 |
| 4 | PLANCHES | 13 | 13 | 0 | 0 |
| 4 | INFOGRAPHIE | 13 | 13 | 0 | 0 |
| 4 | JALONS | 12 | 12 | 0 | 0 |
| 4 | ANIME | 12 | 12 | 0 | 0 |
| 4 | MARQUE | 12 | 12 | 0 | 0 |
| 4 | MAGAZINE | 12 | 12 | 0 | 0 |
| 4 | MASCOTTE | 2 | 1 | 1 (mascotsticker2) | 0 |
| 4 | KIT | 24 | 0 | 24 (N/A) | 0 |
| 4 | EFFETS | 2 | 0 | 2 (cyberpunk, blueprint) | 0 |
| **TOTAL** | | **307** | **267** | **31** | **0** |
