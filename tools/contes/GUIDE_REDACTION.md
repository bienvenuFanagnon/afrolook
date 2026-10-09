# Guide d'écriture — La Case aux Contes

Pour écrire une vague de contes (100 par session) sans perdre la voix ni la qualité des 36 premiers.

## Chaîne de travail

1. Le plan de la vague est dans `vagues/vague-NN.txt` (une ligne par conte : décor, lumière, figures, idée).
2. `node scaffold.js vagues/vague-NN.txt` contrôle le plan ; avec `--write` il crée un brouillon par recueil dans `brouillons/`.
3. On écrit : accroche, origine, morale, 4 à 8 pages. Un brouillon contient encore « À ÉCRIRE » tant qu'il n'est pas fini.
4. On déplace le fichier terminé dans `recueils/`, puis `node build_contes.js` : il refuse tout ce qui est hors cadre (longueurs, listes, doublons).
5. `node build_contes.js --report` montre l'équilibre (régions, étiquettes, décors, lumières, figures) de toute la bibliothèque.
6. `node build_contes.js --upload` envoie. Les réglages faits dans l'admin (masqué, à la une, prix) sont conservés.
7. Ensuite seulement : `node ../i18n/translate.js --source contes --lang en --run` (la traduction ne paie que les textes nouveaux ou modifiés).

## Format d'un conte

- 4 à 8 pages, 50 à 190 mots chacune (visé : 80 à 150). Un conte « court » tient en 5 pages, 400 à 450 mots, 2 à 3 minutes.
- Le premier conte d'un recueil est gratuit. Pour les autres, `gratuites: 2` : le lecteur lit les 2 premières pages, la suivante s'arrête sur un **moment fort** (la question, l'ombre qui bouge, la promesse). Le cliffhanger se prépare dès la page 2.
- `accroche` : 140 signes maximum, deux phrases courtes, une promesse et un manque. Jamais la fin.
- `titre` : 70 signes maximum, concret (« Le puits où le lièvre invita le lion »), jamais « Histoire de… ».
- `morale` : une phrase ou un proverbe, qui n'explique pas le conte en entier.
- Listes autorisées (le contrôleur les vérifie) : décors, lumières, figures, étiquettes, régions — voir l'en-tête de `build_contes.js`.

## Voix

- Une conteuse à la veillée : phrases courtes, rythmées, une image par phrase, des « on raconte que », « un soir », quelques mots du pays (une fois, expliqués par le contexte).
- Dialogues brefs, entre guillemets français. Pas de langage d'école, pas de leçon assénée en fin de page.
- Le lecteur est surtout francophone d'Afrique de l'Ouest et de la diaspora : les noms, les aliments, les gestes doivent sonner juste (mil, calebasse, case, griot…).
- La page 1 pose le lieu et le manque en moins de 4 phrases. La dernière page ferme la boucle posée en page 1.

## Vérité et respect

- **Récit traditionnel** : on écrit une libre réécriture, on le dit (« d'inspiration akan », « Conte traditionnel (peul, Sénégal) » seulement si le motif est bien attesté). On n'attribue jamais à un peuple un récit qu'on a inventé.
- **Histoire** (étiquette `Histoire`) : uniquement des faits recoupés (dates, noms, lieux). On sépare ce qui est source écrite de ce qui est tradition orale (« raconte la tradition », « d'après les chroniqueurs »). Un doute = on retire ou on adoucit. Chaque conte `Histoire` est relu par une personne avant l'envoi.
- Pas de caricature, pas d'exotisme (« tribu », « sauvage »), pas de violence gratuite. Les récits de frisson restent publics tout âge.
- Aucun texte copié : ni de recueils édités, ni de sites. On part du motif, jamais de la phrase.

## Équilibre à tenir

- Régions : ne pas dépasser un tiers pour l'Afrique de l'Ouest dans la bibliothèque entière (la vague 1 en a 29 sur 36 : la vague 2 rééquilibre vers l'Est, le Nord, le Sud et le centre).
- Au moins 4 étiquettes différentes par recueil ; jamais deux contes consécutifs avec le même décor et la même lumière.
- Figures : varier (dans la vague 1, « ancien » apparaît 25 fois et l'éléphant une seule). Le rapport `--report` le montre.

## Contrôle avant envoi

- Lire le premier et le dernier paragraphe à voix haute.
- Vérifier chaque `origine` et chaque conte `Histoire`.
- `node build_contes.js` doit répondre sans problème ; les avertissements (pas de morale…) sont à lire.
- Un nom propre nouveau (peuple, lieu, personnage) est ajouté à `../i18n/glossary.json` avant la traduction.
