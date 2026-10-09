# Afrolook Contes et Récits — plan du module (à valider)

Nom de travail : **La Case aux Contes**. Un grand livre de contes africains qu'on lit comme un manuscrit ancien :
pages de parchemin, gravures en silhouette, ambiance de veillée. Le module finance l'app par les pubs AdMob
(pubs récompensées et plein écran) et par les pièces, comme Étude.

## 1. À qui on s'adresse
- Adultes et familles qui aiment lire, parents qui cherchent une histoire du soir, élèves (culture générale, expression).
- Lecture courte (3 à 12 minutes), un conte à la fois, souvent le soir, sur téléphone.

## 2. Parcours du lecteur
1. **Accueil « La Case aux Contes »** : Conte du jour, rubriques, nouveautés, séries.
2. **Couverture** d'un conte : gravure, titre accrocheur, durée, origine (peuple, pays), prix.
3. **Lecture** : pages de livre, lettrine, gravure, tourner la page, ambiance sonore.
4. **Ouverture gratuite** : environ 35 % du conte se lit sans rien payer, jusqu'à un moment fort. La suite est « scellée ».
5. **Déblocage** : pubs récompensées (jauge gardée) ou pièces ; Pass Veillée 24 h.
6. **Fin du conte** : morale / proverbe, pub plein écran (1 conte sur 2, plafond par jour), « Lire le suivant ».

## 3. Rubriques
| Rubrique | Contenu |
|---|---|
| Contes du soir | Animaux, enfants, morales douces |
| Ruses et malices | Ananse, le Lièvre, Bouki et Malice, Leuk le lièvre, tortue |
| Légendes et royaumes | Soundiata, Yennenga, Abla Pokou, Chaka, reine Nzinga |
| Mystères et frissons | Forêts sacrées, esprits, nuits sans lune (jamais gore) |
| Sagesse et proverbes | Un proverbe, une histoire |
| Récits d'amour | Fleuves, mariages, épreuves |
| Mythes de la création | Origine du monde, du feu, des étoiles |
| Histoires d'Afrique | Récits historiques courts et vrais |

Chaque conte est crédité : « Conte traditionnel (peul, Sénégal) ». Ce sont des **réécritures originales** de contes de
tradition orale, jamais la copie d'un recueil publié (droits d'auteur). Relecture culturelle avant publication.

## 4. Titres accrocheurs (règle d'écriture)
Un titre = une question ou une promesse que le lecteur veut résoudre. Pas de « Le lièvre et la tortue ». Exemples :
- Le jour où la hyène vendit sa voix
- Ce que le lièvre murmura à l'oreille du roi
- La calebasse qui savait tout
- Pourquoi la lune a cessé de descendre au village
- Les trois grains que l'araignée ne voulait pas partager
- Le tambour qui refusait de se taire
- La nuit où Soundiata ne dormit pas
- Celle qui épousa le fleuve
- Le secret du vieux baobab de Ségou
- Quand la tortue défia la foudre

Chaque conte a aussi une **accroche de couverture** (1 phrase qui laisse en suspens) et une étiquette (Fin surprenante, Frisson, Sagesse, Rire).
L'ouverture gratuite s'arrête toujours sur le moment où l'on veut savoir la suite.

## 5. Gratuit, pièces et pubs (mêmes règles que Étude, `AppConfig/contes`)
Valeurs actuelles d'Étude : une pub récompensée = **10 pièces**, une pub plein écran = 7 pièces. Un contenu à P pièces demande ⌈P ÷ 10⌉ pubs.

| Contenu | Prix en pièces | Équivalent en pubs | Remarque |
|---|---|---|---|
| Conte du jour | gratuit | 0 | Entier, avec pub avant/après : sert à faire venir |
| Premier conte de chaque recueil | gratuit | 0 | |
| Ouverture de chaque conte (~35 %) | gratuit | 0 | |
| Conte court (3 à 5 min) | 10 | 1 pub | |
| Récit long (8 à 12 min) | 20 | 2 pubs | |
| Chapitre d'épopée | 20 | 2 pubs | Soundiata, Chaka… en épisodes |
| Recueil de 10 contes | 70 | 7 pubs | moins cher qu'à l'unité (100) |
| Pass Veillée 24 h (tout débloqué) | 80 | 8 pubs, sur 2 jours | |

- Jauge de pubs gardée si le lecteur s'arrête (« encore 1 pub ou 10 pièces »).
- Plafond de pubs récompensées par jour : celui déjà en place.
- **AdMob prioritaire**, pub Afrolook en repli (règle `AdSlot(admobFirst: true)` déjà utilisée dans Quiz/Étude).
- Pubs : native dans les listes, bannière sur l'accueil, plein écran à la fin d'un conte (1 sur 2, 6 par jour max), jamais au milieu d'une page.
- Gold : même règle que dans Étude (les pubs financent les déblocages) — à confirmer.

## 6. Dans le fil d'actualité (sans voler les vues aux posts, Quiz et Étude)
Aujourd'hui (accueil) : Quiz après le 3ᵉ post et le 17ᵉ, Étude après le 10ᵉ et le 27ᵉ, journée sans pub au 5ᵉ.
Proposition : **Conte du jour après le 7ᵉ post**, et un second après le 22ᵉ **seulement si le premier a été ouvert**.
Garde-fous :
- jamais deux cartes de modules à moins de 4 posts d'écart ;
- carte compacte (hauteur d'un post ordinaire), croix pour la masquer jusqu'à demain ;
- si le lecteur a déjà lu le conte du jour, la carte laisse la place à un post ;
- réglable à distance (`AppConfig/contes.feedEvery`, activation par pourcentage d'utilisateurs) ;
- mesure avant/après dans l'admin : posts vus par session, vues par utilisateur actif, durée de session, pubs vues.

## 7. Illustrations : des gravures en silhouette, pas du texte nu
Moteur de scènes dessiné en code (vectoriel, très léger, aucun téléchargement) :
- décors : baobab, savane, village, forêt, fleuve, désert, montagne ;
- lumières : aube, midi, crépuscule, nuit de lune, orage (12 palettes) ;
- personnages en silhouette : lièvre, hyène, araignée, lion, tortue, éléphant, oiseau, singe, crocodile, serpent,
  enfant, ancien, reine, guerrier, griot, tambour, masque, calebasse ;
- cadres : bandes de motifs inspirés du bogolan et des symboles adinkra, lettrine, filigrane.
Chaque conte choisit décor + lumière + personnages dans ses métadonnées : des milliers de contes ont tous leur gravure.
Plus tard : couvertures illustrées sur mesure pour les contes vedettes.

## 8. Ambiance sonore
Générée par le code (comme les sons du Quiz) : bourdon grave chaud, petites notes de kora en gamme pentatonique,
crépitement de feu, léger souffle de nuit. Volume bas, bouton pour couper, mémorisé ; coupée si le téléphone est en silencieux ;
suspendue quand l'application passe en arrière-plan.

## 9. Administration (comme Étude)
- Indicateurs : lecteurs, contes ouverts, taux de fin, page d'abandon, déblocages par pubs et par pièces, pubs vues (récompensées / plein écran),
  revenu estimé, clics de la carte du fil, top des contes, performance du Conte du jour.
- Gestion : activer / masquer un conte, mettre à la une, programmer le Conte du jour, régler les prix, signalements.
- Comparatif de modules : part du temps et des vues entre fil, Quiz, Étude et Contes.

## 10. Technique (réutilise Étude)
- Contenu : `tools/contes/stories/*.md` + validateur + `node tools/contes/build_contes.js [--upload]` (même chaîne que `tools/etude`).
- Firestore : `ContesIndex/{recueil}` (fiches légères, une lecture par recueil), `ContesStories/{id}` (titre, accroche, ouverture gratuite, métadonnées de scène, prix),
  `ContesText/{id}` (texte complet, **non lisible par l'app** : fourni seulement par le serveur après déblocage).
- Fonctions serveur : `conteGetState`, `conteOpen`, `conteUnlock` (pièces), `conteAdStep` (après une pub récompensée), `conteFinish`.
- Coûts : un conte = un seul document de texte (une lecture), mis en cache sur le téléphone après déblocage ; fonctions en fraction de CPU.
- App : `lib/pages/contes/`, peintre de scènes, lecteur de pages, `ContesFeedCard`, tuile dans le hub « Quiz et Étude », écran admin.

## 11. Étapes
1. **Fondations** : serveur, configuration, chaîne de contenu, bibliothèque et lecteur, moteur de scènes, 30 contes (3 recueils).
2. **Monétisation et fil** : pubs, pièces, jauge, Pass Veillée, carte « Conte du jour », admin.
3. **Contenu** : vagues de 100 contes par session (300 puis 1 000), ambiance sonore, traductions anglaises.
4. **Plus tard** : narration audio, couvertures sur mesure, séries hebdomadaires, concours d'écriture de contes par les créateurs.

## 12. Décisions à valider
- Nom du module et de la rubrique dans l'app.
- Part gratuite d'un conte (35 %) et prix proposés.
- Le Conte du jour est gratuit en entier.
- Position dans le fil et nombre de cartes.
- Ambiance sonore active par défaut (avec bouton pour couper).
- Gold sans pub dans Contes, ou comme dans Étude.
- Langue : français d'abord, anglais ensuite.
- Relecture culturelle : qui valide les récits avant publication.

---

# État de l'implémentation (octobre 2026)

## Construit et déployé
- **Serveur** (`functions/src/contes/contes.ts`) : `conteGetState`, `conteOpen`, `conteUnlock`, `conteFinish`, `conteTrack`, `conteAdmin`, `conteAdminStory`.
  Le texte verrouillé ne quitte jamais le serveur : `conteOpen` n'envoie que les pages gratuites tant que le conte n'est pas débloqué (morale comprise).
- **Contenu** : 6 recueils, **36 contes** originaux (`tools/contes/recueils/*.txt`, ~425 mots par conte, 4 à 6 pages), validés et envoyés par
  `node tools/contes/build_contes.js --upload`. Le premier conte de chaque recueil est gratuit, la fin de la partie gratuite tombe sur un moment fort.
- **Application** : `lib/pages/contes/` (accueil, lecteur, déblocage, gravures, style), `lib/services/contes/` (service, ambiance sonore),
  `lib/widgets/feed/sections/contes_feed_card.dart`, tuile dans le hub Quiz et Étude, `lib/pages/admin/contes_admin_page.dart`.
- **Gravures** (`conte_scene.dart`) : 5 lumières × 7 décors × 20 silhouettes dessinés en code ; chaque page du livre a sa propre variante.
- **Polices** : Cinzel Decorative et Crimson Text (licence SIL OFL, `assets/fonts/contes/`).
- **Ambiance** : bourdon, kora, feu, grillons générés par le code (`conte_ambience.dart`), bouton pour couper (choix mémorisé), mise en pause en arrière-plan.
- **Déblocage** : pubs avec récompense (jauge gardée), pub plein écran, pièces, recueil complet, Pass Veillée 24 h. **Quand aucune pub n'est disponible**
  (ou qu'une pub vient d'échouer), le lecteur reçoit une **lecture offerte** (2 par jour, `freePerDay`), sinon il paie en pièces : il n'est jamais bloqué.
- **Lecteur** : les contes non lus passent en premier (en alternant les recueils, « à la une » d'abord), les contes déjà ouverts vont dans « Mon historique ».
- **Fil** : carte compacte après le 7ᵉ post (conte du jour, gratuit en entier, propre à chaque lecteur) et après le 22ᵉ post (autre conte non lu, seulement si le
  premier a été ouvert) ; croix pour la masquer jusqu'à demain. Les positions sont fixes dans le code ; `AppConfig/contes.feedEnabled` l'active ou la coupe.

## Pass « sans pub » 30 jours (Quiz, Étude, Contes)
- `moduleAdFreeBuy` (`functions/src/modules/adFree.ts`) : le lecteur paie en pièces ; `Users.modulesAdFreeUntil` est écrit par le serveur (champ protégé dans les règles).
  Les achats s'ajoutent (120 jours au maximum devant soi).
- Il retire **les pubs passives** : bannières, pubs dans les listes, pubs plein écran de fin de niveau, de chapitre ou de conte (`ModuleAds`, `quiz_ads.dart`).
  Il ne retire **pas** les pubs que le lecteur choisit pour débloquer un contenu ou gagner un cœur.
- Réglages : `AppConfig/modules` (`adFreePrice`, `adFreeDays`, `adFreeEnabled`), relus toutes les 60 s.
- Offre affichée : hub Quiz et Étude, accueil Quiz, accueil Étude, accueil Contes, et un lien discret sous la pub de la page de lecture d'un conte.

### Calcul du prix (500 pièces)
Hypothèses prudentes (eCPM non mesuré par format) : interstitiel ≈ 2 $, native ≈ 0,5 $, bannière ≈ 0,15 $ pour 1 000 affichages.
Un lecteur très actif voit environ 60 interstitiels, 160 natives et 300 bannières par mois dans les trois modules :
60 × 2/1000 + 160 × 0,5/1000 + 300 × 0,15/1000 ≈ 0,12 + 0,08 + 0,045 ≈ **0,25 $ (≈ 150 FCFA)**. Avec des eCPM doubles : ≈ 0,5 $ (≈ 300 FCFA).
500 pièces = ≈ 300 FCFA si les pièces sont achetées (≈ 200 FCFA si elles ont été gagnées) : le pass couvre le lecteur le plus rentable.
Un lecteur moyen rapporte 4 à 8 fois moins : ceux qui achètent sont les plus gros consommateurs de pubs, d'où le prix volontairement élevé.
À recaler avec le revenu réel par utilisateur (AdMob) : modifier `adFreePrice` suffit.

## Mesures
`conteAdmin` : lecteurs, actifs, taux de fin, ouvertures par jour, déblocages (pubs, pièces, lectures offertes), pubs regardées, pièces dépensées,
carte du fil (affichages, clics, croix), ambiance coupée, contes les plus ouverts et terminés, pages d'abandon, nombre de pass sans pub actifs, gestion des contes
(masquer, à la une, prix).

## Copie sur le téléphone (`ContesCache`)
- Un conte **débloqué** (gratuit, acheté, conte du jour, pass) est gardé dans le dossier de l'application (`contes_cache/<uid>_<id>.json`, ≈ 3 Ko, 80 contes au maximum, le plus ancien part d'abord).
- À la réouverture, le téléphone relit le fichier et le serveur n'enregistre que la lecture (`conteTouch` : une écriture, aucun document de texte relu).
  `conteOpen` renvoie `cacheUntil` : 0 = sans limite (gratuit, débloqué), sinon fin du conte du jour ou du pass.
- La copie est refusée (et supprimée) quand : le texte français a été corrigé (`rev` de la fiche ≠ `rev` de la copie), la langue servie n'est plus la bonne
  (une traduction est arrivée, ou l'utilisateur a changé de langue), la date de fin est passée, ou le nombre de pages ne correspond plus.
- Un conte verrouillé n'est jamais écrit sur le disque. Toute erreur de disque est ignorée : on retombe sur le serveur.
- Mesure : `cachedOpens` (« dont depuis le téléphone ») dans l'admin, à comparer aux ouvertures totales.

## Traduction (préparée, non lancée)
- Une seule fois, à la construction : `tools/i18n/translate.js --source contes --lang en` (Google Cloud Translation, 20 $ le million de caractères, 500 000 gratuits par mois).
  Cache `tools/i18n/cache/contes.en.json` (clé = sha1 du texte français) : un texte déjà traduit n'est jamais repayé ; un conte modifié ne coûte que ses pages modifiées.
  Les noms propres sont protégés par `tools/i18n/glossary.json`.
- `build_contes.js` fusionne : fiche (`tr.en` = titre, accroche, origine, dans l'index) et texte (`ContesText.i18n.en` = pages, morale). Corrections à la main :
  `tools/i18n/overrides/contes.en.json` (`{ "<id>": { "t", "h", "o", "morale", "pages": [] } }`), prioritaires sur la machine. Un conte n'est publié en anglais que s'il est **complet**.
- Application : `conteOpen({lang})` sert l'anglais s'il existe, sinon le français ; les fiches prennent la langue de l'application (`trCurrentLanguage`).
- Coût mesuré (estimation) : 36 contes ≈ 95 000 caractères ≈ 1,90 $ (0 $ avec le quota gratuit). Pour 136 contes : ≈ 7 $. Quiz ≈ 10 $, Étude ≈ 25 $.
- À faire avant de lancer : relire à la main les 36 titres et accroches traduits (`--show`), compléter le glossaire pour les nouveaux noms.

## Nouvelles vagues
- `tools/contes/GUIDE_REDACTION.md` : format, voix, règles de vérité (étiquette `Histoire`), équilibre des régions.
- `tools/contes/vagues/vague-02.txt` : plan de la vague 2 (100 contes, 10 recueils). **Écrite** : recueils 07 à 16 dans `tools/contes/recueils/` (les identifiants et quelques
  scènes ont été ajustés en écrivant ; les fichiers de `recueils/` font foi, le plan sert de mémoire). Bibliothèque : 16 recueils, 136 contes, environ 51 600 mots.
- `build_contes.js --report` : état et équilibre de la bibliothèque.
- **Contrôle des contes d'histoire** : les 18 contes de la vague 2 ont été confrontés à des sources en ligne et corrigés (voir `docs/CONTES_SOURCES.md`). Pour tout nouveau conte d'histoire : un conte dont l'en-tête contient `# relecture OBLIGATOIRE` (faits datés, personnages réels) est envoyé **masqué**.
  Une personne le relit (les points à vérifier sont listés dans le commentaire), puis son identifiant est ajouté à `tools/contes/relu.txt` et l'envoi suivant le publie.
  Les contes masqués sont exclus du « conte du jour » et du compte d'un recueil.
- `build_contes.js` : minimum de 50 mots par page (les pages d'histoire sont plus denses que celles des contes).

## À faire ensuite
- Lancer la traduction anglaise des contes (puis quiz et étude) après relecture de l'échantillon.
- Faire relire les 18 contes d'histoire masqués (liste : `node tools/contes/build_contes.js` puis `relu.txt`), puis traduire la bibliothèque ; recueils d'épopées en chapitres ensuite.
- Servir `lang` dans les fonctions du Quiz et de l'Étude quand leurs traductions seront prêtes.
