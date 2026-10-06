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

**Première épreuve offerte** : dans chaque parcours, la première épreuve (composition de classe, examen ou attestation) est gratuite. Les suivantes se débloquent avec des pièces ou des pubs.

**Règle d'équivalence pub / pièces** (une seule valeur à régler : `adValueCoins` dans `AppConfig/etude`) :
- Une pièce vaut 0,4 FCFA (25 pièces pour 10 FCFA). Une pub récompensée rapporte *eCPM ÷ 1000* dollars, soit à peu près `eCPM × 0,6` FCFA par pub (1 dollar ≈ 600 FCFA).
- On donne au joueur au plus 70 % de ce que la pub rapporte, ce qui donne **V ≈ eCPM en dollars** (en pièces par pub).
- Exemples : eCPM 1 $ → 1 pièce par pub ; eCPM 3 $ → 3 pièces ; eCPM 6 $ → 6 pièces.
- Valeur actuelle : **V = 3** (hypothèse prudente pour la zone UEMOA, tant que le vrai eCPM n'est pas connu). Le circuit existant « Récompenses » donne 2 pièces par pub, soit un eCPM supposé de 2 $.
- Un contenu à P pièces demande **⌈P ÷ V⌉ pubs**, avec le plafond de pubs par jour déjà en place (10) : chapitre 20 pièces = 7 pubs ; composition 30 pièces = 10 pubs ; examen 60 pièces = 20 pubs sur deux jours.
- Les gros contenus se débloquent **par étapes** : chaque pub remplit une jauge, gardée si le joueur s'arrête. Il voit toujours « encore 3 pubs ou 15 pièces ».
- Pas de pub pour les comptes Gold (comme partout dans l'app).
- À faire avec le vrai chiffre : relever dans AdMob (Rapports, format « Avec récompense », par pays) l'eCPM de la zone, puis régler V.

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
3. Valeur de la pub : régler V avec le vrai eCPM des pubs récompensées (voir section 4).
4. Examens et compositions : première épreuve offerte, puis pièces ou pubs.
5. Accepter dès maintenant des enseignants partenaires, ou plus tard.

## 10. Pays : UEMOA / BCEAO d'abord

Pays : **Togo** (départ), **Bénin**, **Burkina Faso**, **Côte d'Ivoire**, **Mali**, **Niger**, **Sénégal**, **Guinée-Bissau**. Les autres pays viendront ensuite.

**Principe** : un tronc commun ouest-africain francophone, plus une couche propre à chaque pays.
- **Commun** (une seule rédaction pour les 7 pays francophones) : mathématiques, physique-chimie, SVT, français, anglais, philosophie, informatique, économie. Les programmes se ressemblent beaucoup.
- **Propre à chaque pays** : histoire-géographie et éducation civique (histoire nationale, institutions), noms des diplômes et des séries, formats des examens (nombre d'épreuves, coefficients), concours nationaux.
- **Guinée-Bissau** : système lusophone (portugais). Parcours séparé, contenu en portugais : à traiter en dernier de ce groupe.

| Pays | Brevet | BAC (séries) | Notes |
|---|---|---|---|
| Togo | BEPC | BAC I, BAC II (A4, C, D, E, F, G…) | Pays pilote |
| Bénin | BEPC | BAC (A, B, C, D, E, F, G…) | |
| Burkina Faso | BEPC | BAC (A, C, D, E, F, G…) | |
| Côte d'Ivoire | BEPC | BAC (A, C, D, E, F, G…) | |
| Mali | DEF | BAC (séries Sciences, Lettres, Économie…) | À confirmer |
| Niger | BEPC | BAC (A, C, D, E…) | |
| Sénégal | BFEM | BAC (L, S1, S2, S3, G, T…) | Séries propres au pays |
| Guinée-Bissau | 9.º ano | 12.º ano | Portugais |

**Ordre de travail pour chaque pays** (le pays pilote sert de modèle) :
1. Fiche pays : diplômes, séries, matières, coefficients, concours principaux (à vérifier avec des enseignants du pays).
2. Parcours : classes, matières et chapitres d'après le programme officiel.
3. Contenu commun réutilisé, puis contenu propre (histoire-géo, éducation civique) rédigé pays par pays.
4. Un enseignant ou étudiant relecteur du pays valide le premier lot.
5. Ouverture du pays dans l'app (détecté d'après le pays du profil, comme pour le Quiz).

**Ordre des pays** : Togo, Bénin, Côte d'Ivoire, Burkina Faso, Sénégal, Mali, Niger, puis Guinée-Bissau.

**Université et emploi** : les mêmes contenus servent à tous les pays (informatique, maths, entretien d'embauche) ; seuls les concours et les exemples locaux changent.

## 11. État de l'étape 1 (réalisé)

- **Serveur** (`functions/src/etude/etude.ts`) : `etudeGetState`, `etudeStartTrack`, `etudeOpenChapter`, `etudeStart`, `etudeAnswer`, `etudeFinish`, `etudeUnlock`, `etudeVerifyDiploma`.
- **Parcours** : classes à valider (composition de 20 questions, 50 %), diplôme du parcours (BEPC, BAC D, Licence d'Informatique) quand toutes les classes sont validées, attestations par domaine (70 %). Le joueur choisit sa classe de départ ; le diplôme d'avant se déclare ou se gagne.
- **Déblocage** : premier chapitre de chaque matière gratuit, plus **un chapitre offert par jour** ; chapitres, pass de classe, compositions, examens et attestations en pièces ou en pubs (jauge en pièces équivalentes) ; première épreuve de chaque parcours offerte. Prix (pièces) : chapitre 9, composition 15, attestation 18, examen 24, pass de classe 54. Pubs : avec récompense = 3 pièces (3 pubs pour un chapitre), plein écran = 2 pièces (5 pubs pour un chapitre).
- **Contenu** (`tools/etude/`) : `structure.json` + un fichier texte par chapitre (`content/*.txt`, 15 questions et une fiche) ; `node tools/etude/build_etude.js [--upload]`.
- **Contenu publié** : collège 6e à 3e (36 chapitres, BEPC), seconde, première D et Terminale D (18 chapitres, BAC D), Licence d'informatique L1, L2, L3 (28 chapitres), entretien d'embauche (5), soit 1 260 questions. Les chapitres n'ont pas encore été relus par des enseignants.
- **App** : le Quiz et Étude forment un seul module, **« Quiz & Étude »** (page d'accueil `quiz_etude_hub_page.dart` avec deux grandes cartes). Il remplace Afrolove dans la barre de navigation, prend la tête de « Applications » dans le menu, et Afro Love passe en bas du menu. La page Quiz garde une carte vers Étude.
- **Admin** : module « Étude » du tableau de bord admin (fonction `etudeAdmin`).
- **À faire ensuite** : relire le contenu avec des enseignants, pays suivants (section 10), séries lycée A, C, E…, plus de chapitres par classe, examens blancs, révision espacée, duels.

## 12. À faire plus tard (après un premier suivi de l'utilisation)

On met en ligne ce qui existe, on regarde l'utilisation dans l'admin (module « Étude ») et on décide ensuite.

1. Régler la valeur des pubs avec le vrai eCPM AdMob (`adValueCoins`, `interstitialValueCoins` dans `AppConfig/etude`).
2. Faire relire le contenu publié par des enseignants, puis corriger d'après les signalements.
3. Plus de chapitres par classe et par matière ; français, anglais, philosophie et histoire-géo au lycée.
4. Autres séries du lycée : A, C, E, F, G.
5. Pays suivants de l'UEMOA (section 10) avec leur histoire-géo, leur éducation civique et leurs diplômes.
6. Examens blancs chronométrés, révision des questions ratées, duels et classements par filière ou université.
7. Rappels de révision, fiches PDF, enseignants partenaires, tuteur par IA avec plafond de coût.
8. Traduction complète de l'interface dans les 8 langues.

## 13. Prochaine étape : universités et domaines

Le plan détaillé (liste des domaines, priorités, volumes, évolutions de l'application, marche à suivre) est dans `docs/ETUDE_UNIVERSITES.md`. Le travail se concentre désormais sur l'université et les attestations.

## 13. Attestations « Intelligence artificielle »

Deux attestations (non officielles) : **IA — bases** (c'est quoi l'IA, écrire un prompt, vérifier/éthique, familles d'outils) et **IA pour vendre, créer et programmer** (vente de produits, affiches et images, mots-clés/SEO/hashtags, code-Excel-SQL, réseaux sociaux), avec des prompts modèles dans chaque fiche. Contenu : `tools/etude/content/ia_*.txt`, parcours `cert_ia` et `cert_ia_pro` dans `structure.json`.

## 14. Publicité dans Quiz & Étude

- Bannière sous les questions (écrans ≥ 700 px de haut seulement), pub dans les listes (accueil Quiz, accueil Étude, classe, chapitre), bannière sur l'écran de résultat.
- Pub plein écran à la fin d'un niveau réussi : Quiz tous les 3 niveaux (max 6/jour, réglable `AppConfig/quiz`), Étude tous les 3 niveaux (max 6/jour).
- Jamais pendant une question, jamais pour les comptes Gold (`AdGate`).
- iPhone : pubs de test Google tant que `AppConfig/ads.units.ios` est vide (voir docs iOS ci-dessous).

## 15. Gold et pubs dans Étude

Pour le moment, l'abonnement Gold ne retire pas les pubs dans Afrolook Étude (les pubs y financent les déblocages) : `AdGate.subscriptionBypass` est actif tant qu'une page Étude est ouverte (mixin `EtudeAdBypass`). Le reste de l'app, et le Quiz, gardent la règle Gold = aucune pub. Pour revenir en arrière : retirer `with EtudeAdBypass` des pages `lib/pages/etude/`.

## 16. Premiers parcours universitaires ajoutés

- **Sciences exactes (MPC) — Licence 1** (`univ_mpc`, 12 chapitres, 180 questions) : mathématiques (limites, dérivation, matrices, complexes), physique (cinématique, dynamique, électricité, thermodynamique), chimie (atome, liaisons, solutions, réactions).
- **Économie, Finance et Comptabilité — Licence 1** (`univ_efc`, 12 chapitres, 180 questions) : économie (marché, macro, monnaie et BCEAO), comptabilité SYSCOHADA (bilan, comptes, charges et produits, plan comptable), finance (intérêts, actualisation, ratios), statistiques et probabilités.
- Chaque parcours a son examen de Licence 1 (40 questions, 50 %) et un certificat non officiel. Contenu : `tools/etude/content/mpc_*.txt` et `efc_*.txt`, parcours dans `structure.json`.
- Reste à faire : L2 et L3, relecture par des enseignants, page « facultés » et tronc commun (voir `docs/ETUDE_UNIVERSITES.md`).

## 17. Droit (OHADA) et Sport (STAPS)

- **Droit (avec le droit OHADA) — Licence 1** (`univ_droit`, 12 chapitres) : introduction au droit civil (règle de droit, personnes, contrat), droit constitutionnel (État et pouvoirs, libertés fondamentales), droit OHADA (traité et organes, commerçant et RCCM, sociétés commerciales, sûretés et recouvrement), pénal, procédure et travail.
- **Sport (STAPS) — Licence 1** (`univ_sport`, 12 chapitres) : anatomie et physiologie, entraînement (qualités physiques, principes, échauffement et prévention), nutrition et premiers secours, règles du football, athlétisme, basket-ball, olympisme et organisation du sport.
- Ils s'ajoutent aux parcours existants sans mise à jour de l'application : le catalogue est lu sur le serveur.

## 18. Licences 2 (MPC, Économie-Finance-Comptabilité, Droit, Sport)

Quatre parcours passent de « Licence 1 » à « Licences 1 et 2 » : `univ_mpc`, `univ_efc`, `univ_droit`, `univ_sport` (+ 8 chapitres chacun, soit 32 chapitres et 480 questions).
- MPC L2 : intégrales, équations différentielles, espaces vectoriels et déterminants, ondes et optique, magnétisme et induction, second principe, cinétique, chimie organique.
- Économie-Finance-Comptabilité L2 : croissance et développement, commerce international, amortissements, stocks, TVA et paie, coûts et seuil de rentabilité, marketing, marchés financiers et BRVM.
- Droit L2 : biens, responsabilité civile, famille, procédure civile, droit administratif, procédures collectives et arbitrage OHADA, droit international.
- Sport L2 : filières énergétiques, biomécanique, psychologie, planification, nutrition de performance, organisation des clubs, pédagogie, volley-ball et handball.
- L'examen de ces parcours porte désormais sur les deux années (50 questions, 50 %) et délivre un certificat « Licences 1 et 2 ».

## 19. Licences 3 (parcours complets)

MPC, Économie-Finance-Comptabilité, Droit et Sport ont maintenant leurs trois années (Licence 1, 2 et 3). Chaque Licence 3 ajoute 6 chapitres (90 questions) :
- MPC L3 : séries, fonctions de plusieurs variables, physique quantique, ondes électromagnétiques, thermochimie et équilibres, électrochimie.
- Économie-Finance-Comptabilité L3 : comptabilité analytique, SIG et CAF, budgets et tableaux de bord, management et GRH, entrepreneuriat et plan d'affaires, politiques économiques et convergence UEMOA.
- Droit L3 : contrats commerciaux (vente, bail, transport), droit fiscal, propriété intellectuelle et OAPI, droit pénal spécial, droit du travail collectif, droit du numérique.
- Sport L3 : adaptations à l'entraînement, musculation, traumatologie et rééducation, sport santé, dopage et éthique, sport et société.
- L'examen de licence porte sur les trois années : 60 questions, 50 % pour réussir, avec un certificat « Licence » non officiel.
- Total Étude : 11 parcours, 197 chapitres, 2 955 questions.

## 20. Santé, Gestion et Marketing (Licence 1)

Trois nouveaux parcours de Licence 1 (12 chapitres, 180 questions chacun) : `univ_sante` (anatomie et physiologie, santé publique, soins de base, nutrition et éthique), `univ_gestion` (management, opérations et projets, finance et prix, communication et outils numériques), `univ_marketing` (fondamentaux, communication, marketing digital, vente et mesure). Les Licences 2 et 3 restent à écrire. Total Étude : 14 parcours, 233 chapitres, 3 495 questions. À relire par des professionnels (santé : soignants ; gestion et marketing : enseignants).
