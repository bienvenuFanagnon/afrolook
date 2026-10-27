# Organisation du travail : dossiers, conservation de l'existant et agents

Dernière mise à jour : **27 octobre 2026**. Statut : **instructions du propriétaire consignées ; RIEN N'EST ENCORE MIS EN PLACE.**
Ce document est la mémoire de ces instructions. Il sera exécuté par l'agent qui reprend le projet, **après avoir posé toutes ses questions au propriétaire** (règle de `docs/PROJET_MEMOIRE.md`, section 1). Le résumé et le suivi sont dans `docs/PROJET_MEMOIRE.md` (sections 5.1, 6 et 11).

> Règle du propriétaire (27/10/2026) : **tout ce qu'il dit doit être consigné dans la mémoire du plan** ; l'agent qui écrit la mémoire **ne met rien en place lui-même** : il consigne, l'agent suivant exécute.

---

## 1. Instructions du propriétaire (consignées telles que données)

1. **Conserver la version actuelle du projet, avec Firebase, ailleurs, au cas où il y aurait un problème** pendant la migration.
2. **Le nouveau frontend (application Flutter) et l'API vont dans des dossiers séparés**, distincts du projet actuel.
3. **Le projet actuel doit rester accessible** : pour pouvoir **consulter et purger les données** qu'il contient, et pour **comprendre** comment l'application fonctionne (ce qui nourrit la création de la nouvelle API).
4. **Créer trois agents** :
   - un agent qui **travaille sur l'API** ;
   - un agent qui **fournit les informations de l'application** (celui qui connaît l'application actuelle) ;
   - un agent qui **supervise le travail**, **rappelle toujours la mémoire** et **s'assure que tout est bon**.
5. **Les comptes de l'application** ont une gestion d'équipe (stagiaires, collaborateurs, administrateurs). Il faut **trouver un autre moyen de reconnaître les administrateurs** : ce ne doit **pas** être simple de se déclarer administrateur en changeant une valeur (aujourd'hui, un champ `role` à `ADM` dans le profil) ; c'est dangereux. Voir §4.
6. Tout ce que dit le propriétaire est consigné dans cette mémoire ; **un agent ne met rien en place sans l'avoir demandé** (règle « poser toutes les questions »).
7. **Le frontend n'est pas à recréer** : l'application existe déjà ; le nouveau frontend est **une copie de l'application actuelle, réadaptée à l'API qui sera là**. On ne refait ni les écrans, ni le design, ni les parcours.
8. **Partage du travail** : les **pages et l'interface existent déjà** ; ce qui est à **créer**, ce sont les **traitements** (aujourd'hui les Cloud Functions), qui deviennent **l'API** ; **tout le reste de l'application est à réadapter** seulement. **Firebase ne sert plus ni au traitement des données ni au stockage**, sauf : authentification, notifications (FCM), chats, Remote Config, App Check et **tâches périodiques** (la planification reste chez Firebase et déclenche l'API ; à confirmer, question 15 de la mémoire). Les fichiers vont sur Cloudflare R2.

---

## 2. Organisation cible des dossiers (à créer par l'agent coordinateur)

Proposition, **à confirmer par le propriétaire** (noms et emplacements inclus) :

```
D:\bienvenu\Projets\otherProjets\afrolook\V2\
  afrolookofficiel_v2\        ← LEGACY : application actuelle + fonctions Firebase. Reste accessible, déployé et lisible.
  afrolook-app\               ← frontend Flutter = COPIE de l'application actuelle, RÉADAPTÉE à l'API (couche de données seulement), branchée peu à peu
  afrolook-api\               ← NOUVELLE API Laravel + PostgreSQL (dépôt Git séparé)
  afrolook-coordination\      ← MÉMOIRE UNIQUE + plans + définitions des agents (dépôt Git séparé)
        memoire\              (PROJET_MEMOIRE, MIGRATION_API_LARAVEL, SECURITE_API, AGENTS_ET_ORGANISATION, PAGES_ORPHELINES)
        connaissances\        (fiches par module écrites par l'agent informateur)
        contrats\             (contrat OpenAPI et décisions d'API)
        outils\               (scripts de sonde en lecture seule du projet legacy)
        .claude\agents\       (définitions des trois agents)
```

Points à décider avec le propriétaire (questions à poser) :
- noms et emplacements des dossiers ; un dépôt Git par dossier ?
- la mémoire unique **quitte-t-elle** le dépôt legacy pour le dossier de coordination (recommandé : le legacy reste figé et ne doit pas porter la mémoire vivante) ?
- identifiants de l'application : le nouveau frontend **garde le même identifiant d'application** (`com.afrotok.afrotok`) et le **même projet Firebase `afrolooki`** (comptes, notifications, chats) pour rester une mise à jour de la même fiche des stores.

## 3. Conservation de l'existant (legacy) — à faire AVANT tout changement

À exécuter par l'agent coordinateur, **une étape à la fois, avec l'accord du propriétaire** :
- [ ] **Étiquette Git** sur l'état actuel (`legacy-firebase-AAAA-MM-JJ`) ; ne la publier qu'avec l'accord du propriétaire.
- [ ] **Sauvegarde des données Firebase** : export complet de Firestore (`gcloud firestore export`) vers un compartiment dédié ; copie de Storage déjà présente dans Cloudflare R2 (voir `docs/CDN_R2.md`). Prévenir du coût (quelques centimes à quelques dollars) avant de lancer.
- [ ] **Copie du code** : le dossier actuel reste intact ; archive supplémentaire hors du disque de travail (D : n'a que ~9,9 Go libres) — emplacement à décider.
- [ ] **Le legacy reste déployé et accessible** : fonctions, règles, données. Il continue de servir les utilisateurs pendant toute la migration ; seules les corrections de **sécurité et de production** y sont faites (voir `docs/SECURITE_API.md`, §5).
- [ ] **Accès de sonde en lecture seule** pour l'agent informateur : scripts qui interrogent Firestore sans jamais afficher de données personnelles (noms de champs, types, comptages, exemples anonymisés).
- [ ] **Purge des données** : uniquement sur **demande explicite du propriétaire**, **après sauvegarde**, par lots, avec journal. Aucun agent ne purge de lui-même. (Rappel : suppression de compte à J+15 et purge de toute nouvelle collection, `docs/SUPPRESSION_RESTAURATION_COMPTE.md`.)
- [ ] **Retour arrière** documenté : comment réactiver l'ancienne version de l'application et des fonctions si la migration pose problème.

---

## 4. Reconnaître les administrateurs et l'équipe sans simple champ modifiable

### 4.1 Situation actuelle (constats)
- Administrateur = `Users.role == 'ADM'` (champ du profil), vérifié par les règles Firestore **et** par ~12 fonctions serveur (`news/adminAuth.ts`, `ads/rewards.ts`, `cards`, `contenu`, `contes`, `etude`, `payments`, `team`…). Autres valeurs vues dans le code : `admin`, `ADMIN`, `super_admin`, et dans le modèle `RoleUser { ADMIN, USER, SUPERADMIN }`.
- Équipe (stagiaires, collaborateurs) : collections `TeamProfiles` (nom + liste de « widgets » autorisés) et `TeamMembers/{uid}` (profil attribué) ; fonctions `team/teamHub.ts` ; page `lib/pages/admin/team/team_admin_page.dart`. Aujourd'hui un profil d'équipe ne donne que des statistiques d'inscription, mais **le modèle est le même que celui des droits**.
- **Ces collections ne figurent pas dans `firestore.rules`** : elles tombent sous la règle générale, donc **tout compte connecté peut s'inscrire lui-même dans `TeamMembers`** (faille F13, `docs/SECURITE_API.md`).

### 4.2 Modèle cible (nouvelle plateforme)
1. **Aucun droit n'est stocké dans un document que l'utilisateur peut modifier.** Le profil `users` ne contient ni rôle ni permission.
2. **Table dédiée `staff_accounts`**, écrite seulement par le serveur : utilisateur, **type** (`super_admin`, `admin`, `collaborateur`, `stagiaire`), **profil d'équipe**, statut (invité, actif, suspendu, révoqué), **date de fin** (obligatoire pour un stagiaire), qui l'a créé, qui l'a approuvé, 2FA activée le, dernière revue. Les profils d'équipe actuels (`TeamProfiles`) deviennent des **ensembles de permissions fines** (ex. `stats.inscriptions.voir`, `retraits.valider`, `utilisateurs.suspendre`, `contenu.modérer`), pas des rôles larges.
3. **Attribution contrôlée** : seul un `super_admin`, avec **2FA récente**, peut accorder ou retirer un droit ; l'attribution du niveau `admin` exige la **validation d'un second administrateur** (règle des quatre yeux) et une **invitation à usage unique** envoyée à l'adresse prévue ; tout est **journalisé** (qui, quoi, avant/après, adresse, appareil) et **alerté par e-mail**.
4. **Vérification à chaque requête côté serveur** : le jeton Firebase prouve **qui** est la personne ; la **table `staff_accounts`** (cache court en mémoire) dit **ce qu'elle a le droit de faire**. Les revendications Firebase (`custom claims`) ne servent que d'indice, posées **uniquement par une commande serveur**, jamais l'unique preuve.
5. **Élévation à la demande** : les actions sensibles (retrait, crédit manuel, changement de droits, suppression de compte) demandent une **réauthentification 2FA de moins de 10 minutes**.
6. **Comptes d'équipe dédiés** (à valider avec le propriétaire) : les membres d'équipe utilisent un **compte distinct** de leur compte personnel (adresse dédiée), pour qu'un compte personnel piraté n'ouvre jamais de droits.
7. **Durée de vie** : accès des stagiaires **à échéance automatique** ; revue trimestrielle de tous les accès ; retrait immédiat à la fin d'un contrat.
8. **L'application publique ne révèle pas qui est administrateur** : elle ne lit aucun champ « rôle » ; elle demande à l'API `GET /v1/me/capabilities` (liste de droits calculée par le serveur) et n'affiche des menus d'équipe que si cette liste le permet. L'administration se fait dans un **panneau séparé** (`admin.afrolookmedia.com`, derrière Cloudflare Access + 2FA), voir `docs/SECURITE_API.md` §3.2.
9. **Migration des données d'équipe** : `TeamProfiles` / `TeamMembers` → `staff_profiles` / `staff_accounts` ; les 2 administrateurs actuels (`officiel.afrolook`, `dev.bienvenu`) sont recréés comme `super_admin` avec 2FA, **après vérification par le propriétaire**.

### 4.3 Correctif intermédiaire pour le legacy (à proposer au propriétaire)
- Créer une collection `Staff/{uid}` **écrite uniquement par le serveur** (lecture : sa propre fiche), y reporter les droits actuels (2 administrateurs, membres d'équipe).
- Remplacer, dans les fonctions et les règles, les contrôles `Users.role == 'ADM'` par **un seul utilitaire partagé** lisant `Staff`. `Users.role` n'est plus jamais cru.
- Fermer `TeamMembers` et `TeamProfiles` (écriture serveur seulement).
- À faire **avec les tests dans l'émulateur**, après l'accord du propriétaire ; suivi : `docs/PROJET_MEMOIRE.md` §6.0 (U8).

---

## 5. Les trois agents (définitions à créer ; rien n'est créé)

Chaque agent, **à chaque démarrage**, lit `docs/PROJET_MEMOIRE.md` (ou son équivalent dans le dossier de coordination), puis les documents utiles à sa tâche ; **à chaque fin**, il rend un **RAPPORT** structuré. Un agent **ne décide pas à la place du propriétaire** : s'il lui manque une information, il écrit une rubrique `QUESTIONS` que l'agent principal pose au propriétaire. Tout est en **français**.

### 5.1 Agent « API » (`api-laravel`) — construit
- **Rôle** : construire et tester l'API Laravel (dossier `afrolook-api`) selon `docs/MIGRATION_API_LARAVEL.md` et `docs/SECURITE_API.md`, module par module, dans l'ordre des phases.
- **Entrées** : une fiche de l'agent informateur pour chaque module (écrans, collections, champs, règles, fonctions, pièges) ; le contrat d'API.
- **Sorties** : code, migrations de base, tests, contrat OpenAPI, rapport (ce qui est fait, ce qui reste, écarts avec la fiche).
- **Interdits** : modifier le projet legacy ; décider d'un choix d'architecture non consigné ; stocker un secret dans le code ; contourner la sécurité ; ajouter un droit modifiable par l'utilisateur.
- **Obligations** : tests automatiques sur chaque point d'API (anonyme / autre utilisateur / administrateur), politiques d'autorisation reprenant les règles de l'application actuelle, `Idempotency-Key` sur l'argent.

### 5.2 Agent « Informateur » (`informateur-app`) — connaît l'application actuelle
- **Rôle** : répondre avec précision, **preuves à l'appui** (fichier et ligne), à toute question sur l'application actuelle : écrans, parcours, collections et champs réels, règles de sécurité, fonctions serveur, déclencheurs, appels, cas particuliers, dépendances entre modules, **ce qui doit être porté ou abandonné**.
- **Sorties** : **fiches de module** dans `connaissances/<module>.md` (écrans, données lues et écrites, règles métier, règles de sécurité à porter, appels à convertir en API, pièges connus, scénarios de test de parité), réponses ponctuelles à l'agent API, schéma réel des données (par la sonde en lecture seule).
- **Interdits** : modifier le code ou les données du legacy ; afficher des données personnelles ; purger ; deviner (il dit « non vérifié »).
- **Accès** : lecture du code legacy ; **sonde Firestore en lecture seule** (noms de champs, types, comptages ; jamais de valeurs personnelles).

### 5.3 Agent « Superviseur » (`superviseur`) — contrôle et rappelle la mémoire
- **Rôle** : **rappeler la mémoire** à chaque agent au début de chaque tâche, **vérifier** chaque livrable avant de le déclarer terminé, **s'assurer que tout est bon**, tenir la mémoire à jour.
- **Contrôles** : conformité au plan et aux décisions ; **liste de sécurité** (`docs/SECURITE_API.md`) ; tests exécutés et résultats réels (pas seulement annoncés) ; aucune règle de l'application actuelle perdue (matrice règle → politique → test) ; cohérence entre fiche, API et contrat ; absence de secrets ; qualité du code ; périmètre respecté (Afrolove, pronostics, pages abandonnées non migrés) ; questions du propriétaire posées et réponses consignées.
- **Sorties** : verdict par livrable (**VALIDÉ** / **À CORRIGER** + liste précise) ; mise à jour de `docs/PROJET_MEMOIRE.md` (cases cochées, journal) ; alerte au propriétaire en cas d'écart ou de risque.
- **Interdits** : valider sans avoir vérifié ; modifier le code à la place de l'agent API (il demande la correction).

### 5.4 Protocole de travail
```
Propriétaire ──► Agent principal (coordinateur : pose TOUTES les questions, consigne les réponses)
                      │
                      ├─► Informateur : fiche du module / réponse sur l'existant
                      ├─► API : construit le module à partir de la fiche
                      └─► Superviseur : rappelle la mémoire, contrôle, valide, met à jour le suivi
```
1. Avant un module : le superviseur rappelle la mémoire et le périmètre ; l'informateur livre la fiche ; les **questions** sont posées au propriétaire.
2. Pendant : l'API construit ; les écarts avec la fiche remontent à l'informateur ; rien n'est supposé.
3. Après : le superviseur contrôle (tests, sécurité, parité) et **ne coche la case** dans `docs/PROJET_MEMOIRE.md` §6 qu'après verdict **VALIDÉ**.
4. Le propriétaire reste le décideur : tout choix non consigné est une **question**.

### 5.6 Adaptation du frontend (copie de l'application actuelle)
Principe consigné le 27/10/2026 : **on copie et on réadapte, on ne recrée pas.**
- **Ce qui change** : l'accès aux données. Chaque lecture ou écriture directe dans Firestore, chaque appel de fonction Firebase des modules migrés est remplacé par un appel à l'API (classe `ApiClient`, interrupteurs de modules, version minimale). Les **modèles** peuvent rester les mêmes ; le format des réponses de l'API est conçu pour leur correspondre (contrat d'API issu des fiches de l'informateur).
- **Ce qui ne change pas** : écrans, navigation, design (clair/sombre), textes et traductions, SDK d'authentification, de notifications (FCM), de publicité et d'achat intégré, lecteurs médias, éditeurs.
- **Précision sur « ce qui ne change pas » (27/10/2026, à la demande du propriétaire)** : ce sont des **bibliothèques installées sur le téléphone**, indépendantes de Firebase. Concrètement :
  | Élément | Paquets de l'application (`pubspec.yaml`) | Ce qui reste dans l'application | Ce qui passe dans l'API |
  |---|---|---|---|
  | **Publicité** | `google_mobile_ads` (AdMob), `stack_appodeal_flutter` (Appodeal) | L'**affichage** des pubs (bannières, plein écran, vidéos récompensées, pubs natives du fil), directement par ces services | La **logique serveur autour** : campagnes des annonceurs Afrolook (`Advertisements`), **récompense après une pub regardée** (vérification côté serveur), suivi des revenus, plafonds — module « Pubs » |
  | **Achat intégré** | `in_app_purchase` (Apple App Store, Google Play) | La **fenêtre d'achat** du magasin sur le téléphone | La **vérification du reçu** côté serveur et le **crédit des pièces** (aujourd'hui `verifyApplePurchase`, Google Play, notifications Apple) — module « Portefeuille et paiements » |
  | **Lecteurs médias** | `video_player`, `chewie` (vidéos des publications), `youtube_player_flutter` (YouTube), `just_audio` et `audioplayers` (musique, sons), `agora_rtc_engine` (lives) | Tout : ils **lisent un fichier à partir d'une adresse** | Seulement **l'adresse du fichier** : elle pointera vers Cloudflare R2 (via le CDN) et non plus vers Firebase Storage ; les adresses temporaires d'écoute des musiques payantes sont émises par l'API |
  | **Éditeurs** (photo, vidéo, Studio, cartes) | éditeurs et rendus de l'application | Le **montage** se fait sur le téléphone | L'**envoi du résultat** : adresse signée de l'API vers R2 ; métadonnées et achats dans l'API |
  En résumé : **ce qui s'affiche ou se joue sur le téléphone reste tel quel** ; **seul le traitement derrière** (comptes de pièces, récompenses, vérification des achats, adresses des fichiers) passe dans l'API.
- **Ce qui reste sur Firebase** : authentification, FCM, chats (Firestore), Remote Config, App Check, et la **planification** des tâches périodiques (qui ne fait que déclencher l'API). **Plus aucun traitement ni stockage de données métier.**
- **Ordre** : module par module, dans l'ordre des phases du plan de migration ; pour chaque module, **parité vérifiée** avec l'application actuelle (même résultat à l'écran), puis suppression du code d'accès Firestore devenu inutile.
- **Retrait du code abandonné pendant l'adaptation** : Afrolove, pronostics, pages orphelines confirmées, `firebase_dynamic_links`, ancien code OneSignal et paiements côté téléphone (sécurité).
- **Qui adapte ?** À décider avec le propriétaire (question 14 de la mémoire) : l'agent API, un agent dédié, ou lui. L'**informateur** fournit pour chaque module la liste exacte des endroits de l'application à adapter ; le **superviseur** contrôle la parité.

### 5.5 Mise en œuvre des agents (à faire plus tard)
Les trois agents seront définis comme sous-agents de l'outil (fichiers de définition dans `afrolook-coordination/.claude/agents/`, avec description, outils autorisés et consignes ci-dessus). L'agent principal les appelle selon le protocole. **À faire seulement après validation de ce document par le propriétaire.**

---

## 6. Liste de mise en place (pour l'agent coordinateur)

- [ ] Poser au propriétaire les questions du §2 (dossiers, mémoire, identifiant d'application) et du §4.2 (comptes d'équipe dédiés, niveaux, seuils)
- [ ] §3 : conserver le legacy (étiquette, export Firestore, archive, retour arrière)
- [ ] Créer le dossier de coordination et y **déplacer la mémoire vivante** (le legacy garde un `CLAUDE.md` qui renvoie vers elle)
- [ ] Créer `afrolook-app` (copie de l'application actuelle, dépôt Git séparé, mêmes identifiants Firebase) et `afrolook-api` (dépôt Git séparé)
- [ ] Définir les trois agents (§5) et le protocole (§5.4)
- [ ] Outiller la sonde en lecture seule du legacy (§3)
- [ ] Lancer la phase 0 (`docs/MIGRATION_API_LARAVEL.md` §13) avec le superviseur en contrôle
