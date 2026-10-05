# Étude — plan « Universités et domaines » (à lancer à la prochaine session)

Objectif : faire d'Étude le meilleur compagnon des étudiants. On garde le collège et le lycée tels qu'ils sont, et on concentre l'effort sur l'**université** et les **attestations par domaine**, avec beaucoup de parcours.

## 1. Ce qui existe déjà (à ne pas refaire)

- Parcours : Collège (BEPC), Lycée série D (BAC D), Licence d'Informatique (L1 à L3), attestations « Entretien d'embauche » et « Python ».
- Mécanique prête : classes à valider, composition, examen de diplôme, attestations, déblocage pièces ou pubs, chapitre offert du jour, première épreuve offerte, admin.
- Outils de fabrication : `tools/etude/structure.json` + un fichier texte par chapitre (`tools/etude/content/`), contrôle et import par `node tools/etude/build_etude.js [--upload]`.

## 2. Nouveaux domaines à ajouter (liste de départ)

Chaque domaine devient un **parcours de licence** (L1, L2, L3, diplôme final) et, pour les notions utiles hors cursus, des **attestations**.

### Sciences et technologies
| Domaine | Parcours de licence | Matières clés |
|---|---|---|
| **Mathématiques, Physique, Chimie (MPC)** | Licence Sciences exactes | Analyse, algèbre, probabilités, mécanique, électricité, thermodynamique, optique, chimie générale, chimie organique, chimie des solutions |
| Informatique (existant) | Licence d'Informatique | à compléter : algorithmique avancée, bases de données, réseaux, génie logiciel, IA |
| Électronique, électrotechnique | Licence Génie électrique | Circuits, électronique analogique et numérique, machines électriques, automatique |
| Génie civil et BTP | Licence Génie civil | Résistance des matériaux, béton, topographie, hydraulique |
| Sciences de la vie et de la Terre | Licence SVT | Biologie cellulaire, génétique, écologie, géologie, physiologie |
| Agronomie et élevage | Licence Sciences agronomiques | Sols, cultures, protection des plantes, élevage, économie rurale |
| Environnement et énergies renouvelables | Licence Environnement | Climat, solaire, eau, déchets, développement durable |

### Économie, gestion et droit
| Domaine | Parcours de licence | Matières clés |
|---|---|---|
| **Économie, Finance, Comptabilité (ensemble)** | Licence Économie-Gestion | Microéconomie, macroéconomie, comptabilité générale, **SYSCOHADA**, analyse financière, mathématiques financières, statistiques, marchés financiers |
| Gestion et management | Licence Gestion | Management, marketing, ressources humaines, gestion de projet, entrepreneuriat |
| Banque, finance et assurance | Licence Banque-Finance | Banque, monnaie, **BCEAO et politique monétaire de l'UEMOA**, microfinance, assurance |
| Marketing et communication digitale | Licence Marketing | Marketing de base, réseaux sociaux, publicité, e-commerce |
| Droit | Licence en Droit | Droit civil, constitutionnel, pénal, **droit OHADA**, droit du travail, droit international |
| Sciences politiques et relations internationales | Licence Sciences politiques | Institutions, relations internationales, **UEMOA, CEDEAO, Union africaine** |
| Logistique et transport | Licence Logistique | Chaîne logistique, transport, commerce international, douane |

### Santé
| Domaine | Parcours | Matières clés |
|---|---|---|
| Médecine générale (1er cycle) | PACES / 1re année santé | Anatomie, physiologie, biochimie, biophysique, histologie |
| Soins infirmiers et sage-femme | Licence Sciences infirmières | Soins de base, pharmacologie, santé publique, obstétrique |
| Pharmacie | Pharmacie 1er cycle | Chimie pharmaceutique, pharmacognosie, galénique |
| Santé publique et nutrition | Licence Santé publique | Épidémiologie, nutrition, hygiène, programmes de santé |

### Lettres, langues, sciences humaines
| Domaine | Parcours | Matières clés |
|---|---|---|
| Lettres modernes et communication | Licence Lettres | Littérature africaine et française, linguistique, expression écrite |
| Langues (anglais, allemand, espagnol) | Licence LEA | Grammaire, civilisation, traduction ; préparation TOEIC / TOEFL |
| Histoire-géographie | Licence Histoire-Géographie | Histoire de l'Afrique, histoire du monde, géographie |
| Sociologie et psychologie | Licence SHS | Théories, méthodes d'enquête, psychologie du développement |
| Journalisme et médias | Licence Journalisme | Écriture journalistique, déontologie, audiovisuel |
| Éducation et enseignement | Licence Sciences de l'éducation | Pédagogie, didactique, psychologie de l'enfant |

### Sport et vie active
| Domaine | Parcours | Matières clés |
|---|---|---|
| **Sport (STAPS)** | Licence Sciences et techniques du sport | Anatomie, physiologie de l'effort, entraînement, biomécanique, psychologie du sport, règles des sports, nutrition, premiers secours, management du sport |
| Football et arbitrage | Attestation | Règles du jeu (lois de l'IFAB), tactique, arbitrage |
| Coaching et préparation physique | Attestation | Planification, prévention des blessures |
| Tourisme, hôtellerie, restauration | Licence Tourisme | Gestion hôtelière, accueil, géographie du tourisme |
| Arts, musique et culture | Licence Arts | Histoire de l'art, théorie musicale, production culturelle |

### Attestations transversales (courtes, très demandées)
Entretien d'embauche (existant), Python (existant), puis : bureautique (Word, Excel), Excel avancé et tableaux croisés, comptabilité SYSCOHADA (bases), gestion de projet, entrepreneuriat et plan d'affaires, marketing digital, anglais professionnel (TOEIC), communication et prise de parole, secourisme, droit du travail, finance personnelle, culture générale des concours, logique et tests d'aptitude, rédaction de CV et lettre de motivation.

## 3. Priorités (ordre proposé)

1. **Mathématiques-Physique-Chimie** (domaine phare, matières communes à beaucoup de filières).
2. **Économie-Finance-Comptabilité** avec SYSCOHADA, BCEAO et OHADA : très utile dans l'UEMOA.
3. **Droit** avec droit OHADA.
4. **Sport (STAPS)**.
5. **Santé** (1er cycle, soins infirmiers) et **Gestion / Marketing**.
6. Électronique, génie civil, agronomie, lettres, langues, histoire-géographie.
7. Attestations transversales en continu (bureautique, Excel, TOEIC, entrepreneuriat…).

## 4. Volume visé par parcours

- **Licence complète** : 3 années × 4 à 6 matières × 2 à 3 chapitres, soit 30 à 60 chapitres et 450 à 900 questions.
- **Version de départ (« socle »)** pour chaque domaine : L1 uniquement (8 à 12 chapitres, 120 à 180 questions) pour ouvrir vite, puis on complète L2 et L3 selon l'utilisation.
- **Attestation** : 4 à 8 chapitres et un examen de 30 questions.

## 5. Ce qu'il faut ajouter à l'application

1. **Choix de la faculté** : page d'accueil Étude organisée en « facultés / domaines » (Sciences, Économie-Gestion, Droit, Santé, Lettres, Sport…), avec recherche et filtres, au lieu d'une simple liste de parcours.
2. **Tronc commun** : une matière partagée entre plusieurs parcours (mathématiques, anglais, informatique de base) sans la réécrire, avec progression commune.
3. **Plusieurs parcours en parallèle** : afficher « mes parcours » (déjà commencés) et « découvrir d'autres parcours ».
4. **Attestations** : pages dédiées avec catégories (Informatique, Gestion, Langues, Sport, Vie professionnelle).
5. **Spécialités et options** : après la L2, choix d'une spécialité (par exemple Informatique : réseaux, génie logiciel, IA).
6. **Admin** : tableau par domaine (apprenants, réussite, chapitres les plus difficiles), import de contenu plus simple.
7. **Outil de rédaction** : modèles de fichiers par domaine pour écrire plus vite et mieux (fiche + 15 questions), avec contrôle automatique plus strict (doublons, difficulté).

## 6. Qualité et sérieux

- Contenu écrit à partir des programmes publics des universités de la sous-région ; aucune copie de sujets protégés.
- Chaque domaine est relu par un enseignant ou un étudiant de master avant ouverture large (formulaire de signalement déjà en place).
- Vocabulaire et exemples locaux : UEMOA, BCEAO, OHADA, SYSCOHADA, FCFA, droit du travail togolais.
- Indiquer la source du programme et la date de mise à jour dans chaque parcours.

## 7. Boutique et déblocage (à garder)

- Premier chapitre de chaque matière gratuit, un chapitre offert par jour, première épreuve de chaque parcours offerte.
- Pass de classe, composition, examen et attestation en pièces ou en pubs. Valeur des pubs à régler avec l'eCPM réel.
- Idée : « Pass domaine » (toute une licence) et « Pass attestation » à prix réduit.

## 8. Marche à suivre pour la prochaine session

1. Relire ce plan et valider la liste (retirer ou ajouter des domaines).
2. Mettre à jour `structure.json` avec les nouveaux parcours (facultés, licences, attestations).
3. Écrire d'abord MPC (L1), puis Économie-Finance-Comptabilité (L1) : environ 12 chapitres chacun.
4. Ajouter la page « facultés » et les attestations par catégorie dans l'application.
5. Tester avec un compte de test, déployer, regarder l'utilisation dans l'admin.
6. Continuer domaine par domaine, en suivant ce que les étudiants utilisent le plus.
