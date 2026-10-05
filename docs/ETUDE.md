# Afrolook Étude — plan du module d'éducation

Même univers que le Quiz (mascotte, cœurs, séries, points, classements), mais pour **apprendre, réviser et se préparer aux examens, concours et entretiens**. On avance par étapes ; chaque étape est utilisable seule.

## 1. À qui on s'adresse

| Public | Besoin principal | Exemples |
|---|---|---|
| Collège (6e–3e) | Réviser les cours, préparer le BEPC | Maths, français, SVT, physique, histoire-géo, anglais |
| Lycée (2nde–Terminale) | Contrôles, compositions, BAC | Séries A, C, D, E, F, G… selon le pays |
| **Université** (L1–M2) | Cours, TD, partiels, révisions | Informatique, maths, physique, chimie, économie, gestion, droit, médecine, langues |
| Concours | S'entraîner sous pression | Fonction publique, écoles, santé, police/armée, banques |
| Vie professionnelle | Décrocher un emploi | Entretien d'embauche, tests de logique, anglais pro |

L'application étant surtout utilisée par des étudiants, **l'université et l'emploi passent en premier**, le lycée (BAC) juste après.

## 2. Parcours du joueur

1. **Profil d'étude** (une fois, modifiable) : pays, niveau (collège / lycée / université / concours / emploi), filière ou série, année, matières suivies. Il donne l'écran d'accueil personnalisé et le programme du pays.
2. **Accueil Étude** : objectif en cours (ex. « BAC D dans 74 jours »), série du jour, matière à reprendre, défi du jour, révision conseillée.
3. **Matière → chapitres → leçons** : chaque chapitre est un parcours de niveaux (comme le Quiz).
   - **Fiche de cours** courte (1 à 2 minutes de lecture), avec schéma, formule ou exemple.
   - **Exercices en QCM** par niveaux de 5 questions, avec explication à chaque réponse.
   - **Boss de chapitre** : 10 à 15 questions chronométrées pour valider le chapitre.
4. **Révision intelligente** : les questions ratées reviennent à intervalles croissants (répétition espacée).
5. **Examen blanc** : durée et nombre de questions réels du concours ou de l'examen, correction détaillée et note sur 20 à la fin.
6. **Annales corrigées** (QCM reformulés, jamais de copie de sujets protégés).
7. **Duel et classements** : défi d'un ami, classement par classe, filière, université, pays.

## 3. Le jeu (repris du Quiz)

- **XP et niveaux d'étudiant**, séries (jours d'étude d'affilée), badges (« 7 jours de révision », « Chapitre parfait »…).
- **Cœurs** : mêmes règles que le Quiz, rechargeables avec des pièces ou une pub.
- **Objectif examen** avec compte à rebours et rythme conseillé.
- **Classement hebdomadaire** par université ou lycée, avec cadres et titres (« Major de promo », « Matheux »).
- La mascotte devient le **tuteur** : encouragements, rappels de révision, animations de réussite.

## 4. Ce qui est gratuit, ce qui se débloque

**Principe : tout le monde peut essayer, les contenus complets se débloquent.**

| Contenu | Accès |
|---|---|
| Premier chapitre de chaque matière, quiz du jour, révision de base | Gratuit |
| Chapitres suivants, examens blancs, annales | Pièces **ou** pubs |
| Pass d'un module complet (ex. « Algorithmique L1 ») | Pièces **ou** pubs |
| Pass Examen (ex. 30 jours avant le BAC : tout débloqué, cœurs illimités) | Pièces |
| Fiches PDF de révision, corrigés détaillés | Pièces |
| Cœurs supplémentaires | Pièces **ou** pub |

**Règle d'équivalence pub / pièces** (vous fixez une seule valeur dans la config) :
- *1 pub récompensée = V pièces* (proposition de départ : V = 5 pièces).
- Un contenu à P pièces demande **⌈P ÷ V⌉ pubs**, avec un plafond de pubs par jour pour éviter l'abus.
- Exemples avec V = 5 : chapitre 25 pièces = 5 pubs ; examen blanc 50 pièces = 10 pubs ; module complet 250 pièces = 50 pubs (étalées sur plusieurs jours).
- Les gros modules se débloquent **par étapes** : chaque pub remplit une jauge, le déblocage se fait quand la jauge est pleine, et la jauge est gardée si le joueur s'arrête. Il voit toujours « encore 3 pubs ou 15 pièces ».
- Pas de pub pour les comptes Gold (comme partout dans l'app) : ils paient en pièces ou ont des remises.

**Autres idées à vendre** : booster de série, correction personnalisée d'un devoir par un professeur partenaire, abonnement mensuel « Étudiant » (accès à tout), packs de classe pour un établissement.

## 5. Contenu à produire (ordre de priorité)

### Université
- **Informatique** : algorithmique, Python, C, Java, programmation objet, structures de données, bases de données et SQL, réseaux, systèmes, web, génie logiciel, sécurité, intelligence artificielle, logique et complexité.
- **Mathématiques** : analyse, algèbre, probabilités, statistiques, optimisation.
- **Sciences** : physique, chimie, biologie, électronique, mécanique.
- **Économie et gestion** : comptabilité, finance, marketing, management, droit des affaires.
- **Droit**, **santé** (anatomie, physiologie, pharmacologie), **langues** (anglais, TOEIC/TOEFL).
- Pour chaque matière : programme par année (L1, L2, L3, M1, M2), chapitres, QCM, exercices type partiel.

### Collège et lycée
- Programme officiel par pays (commencer par le **Togo**, puis Bénin, Côte d'Ivoire, Sénégal, Cameroun, Burkina Faso, France).
- Collège : BEPC (maths, français, SVT, PC, histoire-géo, anglais).
- Lycée : séries A, C, D, E, F, G…, BAC blanc, philosophie, langues.

### Concours
- Annales reformulées, tests de culture générale, logique, aptitude, par concours et par pays.

### Emploi et entretien
- **Banque de questions d'entretien** par métier et par secteur (« Parlez-moi de vous », « Vos défauts », « Pourquoi nous ? », questions techniques de développeur, comptable, commercial, enseignant, infirmier…).
- **Meilleures réponses commentées** (méthode STAR, erreurs à éviter, exemples adaptés au contexte africain et international).
- **Simulateur d'entretien** : question chronométrée, le joueur choisit parmi plusieurs formulations de réponse, puis reçoit le commentaire et une note.
- Tests de logique et de psychotechnique, anglais professionnel, aides pour le CV et la lettre de motivation.

## 6. Fabrication du contenu

- Même chaîne que le Quiz : fichiers de questions structurés → contrôle automatique (doublons, longueurs, réponses distinctes) → import dans Firestore. Les erreurs signalées par les joueurs (déjà en place dans le Quiz) arrivent dans l'onglet admin.
- Chaque question porte : pays, niveau, filière, matière, chapitre, difficulté, source (programme), explication.
- **Auteurs partenaires** : enseignants et étudiants brillants peuvent proposer des cours et des questions ; validation admin, puis rémunération en pièces sur les déblocages (même logique que les créateurs de stickers).
- **Qualité d'abord** : relecture par matière, versionnage des contenus, correction rapide des signalements.
- Aucun sujet d'examen protégé n'est copié : questions reformulées, inspirées des programmes officiels.
- Intelligence artificielle (tuteur qui répond aux questions) : **plus tard, avec plafond de coût**, car chaque réponse coûte de l'argent.

## 7. Technique (réutilise le Quiz)

- Nouvelles collections : `EtudeProfiles`, `EtudeCourses` (matières, chapitres), `EtudeLessons`, `EtudeQuestions`, `EtudeProgress`, `EtudeUnlocks`, `EtudeExams`.
- Fonctions serveur sur le modèle du Quiz : démarrer un niveau, répondre, terminer, débloquer (pièces ou pubs avec vérification), examen blanc, révision espacée, classements.
- Débloquer par pub : même circuit sécurisé que les récompenses des pubs déjà en place (vérification côté serveur).
- App : menu Étude, profil d'étude, parcours par matière, lecteur de fiche, mode examen, simulateur d'entretien.
- Admin : tableau de bord Étude (participation par niveau, filière, matière ; taux de réussite par question ; signalements ; déblocages et revenus).
- Traductions : les contenus sont dans la langue du programme ; l'interface suit les 8 langues de l'app.

## 8. Feuille de route (étapes, de la plus utile à la plus large)

1. **Fondations** : profil d'étude, structure matière / chapitre / leçon, parcours de niveaux, déblocage pièces ou pubs, admin de base.
2. **Pilotes** pour valider l'idée :
   - *Informatique L1* (algorithmique, Python, bases de données) ;
   - *Entretien d'embauche* (banque de questions et meilleures réponses) ;
   - *Terminale scientifique du Togo* (maths, physique-chimie, SVT).
3. **Examens blancs, révision espacée, duels et classements** par filière et université.
4. **Extension université** : maths, économie et gestion, droit, santé, langues ; L2, L3, masters.
5. **Collège et lycée complets** pour le Togo, puis pays voisins.
6. **Concours** par pays.
7. **Partenaires enseignants**, cours créés par la communauté, packs d'établissements.
8. Options avancées : tuteur par IA avec plafond de coût, fiches PDF, correction personnalisée.

## 9. Décisions à prendre avant de commencer l'étape 1

1. Public prioritaire : université, BAC, ou les deux en parallèle ?
2. Pays de départ pour les programmes (proposition : Togo).
3. Valeur de la pub : V = 5 pièces par pub vous convient-il ?
4. Gratuit ou payant par défaut pour les examens blancs.
5. Accepter dès maintenant des enseignants partenaires, ou plus tard.
