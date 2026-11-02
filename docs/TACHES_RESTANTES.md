# Tâches restantes avant la mise à jour des stores (liste du 02/11/2026)

Liste établie à la demande du propriétaire : ce qui est prévu mais pas encore fait, pour que le travail continue en son absence, puis tests, puis mise à jour de l'application sur les stores.
Légende : 🤖 je peux le faire seul · 👤 il faut le propriétaire (clé, mot de passe, décision, publication) · 📱 test sur téléphone.
Règles : rien n'est poussé ni soumis aux stores sans accord ; aucune clé n'est jamais écrite dans un message ni dans un dépôt (scripts à saisie masquée) ; production non touchée sans accord.

## 0. Avancement du 02/11/2026 (soir) — les recommandations A1 à A9 et Q1 à Q14 ont été validées par le propriétaire (« on fait tes recommandations »)
Fait (code écrit et testé : 1067 tests de l'API passent, application sans erreur d'analyse ; RIEN n'est poussé, commité ni déployé en production) :
- A1 : super-administrateur du propriétaire créé sur le serveur de TEST (pas en production).
- A3 : date de repli 01/01/2026 pour les comptes sans date de création, dans l'importeur (la production recevra un export frais) ; appliquée aussi au test.
- A4 : « Astuces Vidéo » une seule fois. A9 : API d'administration de la version et des liens des stores (`GET/PUT /v1/admin/settings/app`, permission `config.edit`, journalisée) ; l'écran du site d'administration reste à brancher.
- Orientation des vidéos (`is_portrait`), historique du portefeuille lisible, journal clair du refus « profil introuvable » (serveur).
- **Live Shopping, étape 1 (API + application)** : achat en 1 clic d'un article physique en FCFA avec séquestre, commission 10 %, pénalité d'annulation 10 % après validation du vendeur, livraison estimée et payée à la livraison (le vendeur peut modifier, l'acheteur accepte ou refuse), négociation (3 tours, 24 h, plancher caché), produits épinglés dans un live, litiges tranchés par l'équipe (`shop.manage`), libération automatique à 7 jours et annulation à 72 h sans réponse (`shop-orders:sweep`, toutes les heures). Application : « Mes commandes » (achats, ventes, offres), tarifs de livraison, bandeau de produit épinglé dans le live (acheter, négocier, épingler/retirer).
Reste pour le Live Shopping : essais sur téléphone et corrections visuelles ; étape 2 produits numériques ; étape 3 enchères ; étape 4 billetterie ; étape 5 Talk/PK et invités multiples ; promotions par code ; modération du chat ; part du parrain sur la commission ; traductions des nouveaux écrans (français seulement pour l'instant) ; sortie de la fiche de litige dans l'administration du site.

## 0 ter. À FAIRE AVANT L'IMPORT FINAL (découvert le 02/11/2026) : certification perdue à l'export
L'ancien script d'export n'exportait NI `isVerify` (badge de certification) NI les champs `officialAccount*` des comptes : les comptes certifiés ont perdu leur badge sur le serveur de test. Le script `afrolook-coordination/outils/export/export_ndjson.js` est corrigé et l'importeur reprend maintenant `isVerify` → `users.is_verified` et le profil officiel → `official_accounts` (jamais retiré par un nouvel import). 👤 Il faut REFAIRE l'export des comptes avec le script mis à jour (clé Firebase du propriétaire), puis relancer l'import sur le test pour vérifier, puis en production. L'équipe peut ajouter ou retirer un badge : page « Certifications » du tableau de bord admin (droit `users.certify`).
Autre cause trouvée : le rôle d'équipe `super_admin`/`admin` n'était pas converti en rôle « ADM » dans l'application : le tableau de bord admin n'apparaissait pas (corrigé).

## 0 bis. Avancement du 02/11/2026 (nuit) — fin de l'étape 1 du Live Shopping
Fait et testé (1074 tests API) : notifications de commande et d'offre (8 langues, `ORDER_*`, `OFFER_*`), administration (`GET /v1/admin/live-shop/orders`, `/stats`, `/disputes`, `POST .../resolve` : remboursement ou paiement du vendeur, même sans litige), écran d'administration dans l'application (menu, visible avec le droit `shop.manage`), options de vente en direct dans le formulaire d'article (achat en un clic, prix plancher, stock, vente flash), bouton « Live » sur la page de la boutique, menu : Boutique et Mes commandes à la place de Mon journal et Découverte, correctif du plantage de « Publier » (abonnement de la boutique jamais rempli), jeton de live avec uid 0, heure de la base en UTC, images de couverture des lives dans le fil, doublons de la liste des lives, message d'erreur précis à l'achat.
Reste pour la vente en direct : essai de bout en bout sur téléphone avec deux comptes ; paiement Mobile Money direct (aujourd'hui : solde FCFA rechargé avant) ; produits numériques ; enchères ; billetterie ; codes promo ; part du parrain ; traduction des écrans dans les 7 autres langues.

## 1. Avant tout : l'équipe d'administration
- 👤 Créer les comptes d'administration (`php artisan staff:bootstrap <id>` ; identifiant du propriétaire : voir la mémoire) : d'abord sur le serveur de test, puis en production. **Pas encore fait.**

## 2. Code en cours (écrit, non poussé, à vérifier)
- 🤖 Orientation des vidéos (portrait/paysage) : champ `is_portrait` dans l'API (migration, import, publication), lecture et envoi par l'application, détection à l'ouverture pour les anciennes vidéos. Tests API : 1055 passent. Reste : déployer sur le serveur de test (👤 pousser l'API), relancer l'import des publications pour récupérer l'orientation d'origine, 📱 tester avec une vidéo verticale et une horizontale.
- 🤖 Historique du portefeuille : gains de tâches/missions/parrainage/hebdo avec phrases claires (« Tâche terminée : … », « Partage et gagne : gains versés »…) et types connus (plus de « Inconnu »). Reste : 📱 vérifier avec une vraie libération de gain sur le serveur de test.
- 🤖 Modal « Découvrez d'autres posts » une seule fois ; pages Travail et Partage et gagne allégées ; cartes d'articles restylées. Reste : 📱 contrôle visuel (mode clair et sombre, petit écran).
- 🤖 Traductions : les nouveaux textes sont en français (repli sur le français dans les autres langues) ; ajouter les 7 autres langues avant la publication.
- 🤖 Commits locaux de l'application (branche d'API) quand le propriétaire le demande.

## 3. Serveur : à terminer
- 👤 Clés IA du Journal (comptes Cloudflare Workers AI) : script masqué `afrolook-api/deploy/poser-cles-ia.sh` (test puis production). Sans elles, aucun nouvel article.
- 🤖 Réglage public `news` (`enabled`, `feedEnabled`) : posé sur le test ; à poser en production au moment de la bascule.
- 👤 Autres secrets du serveur (script masqué à écrire sur le modèle de Torox) : stockage R2, FeexPay, Agora, FCM, clé de signature des pubs.
- 🤖 Fil infini des pages Sport / Événements / Looks (API).
- 🤖 Importeurs manquants : campagnes de partage, profils partageurs, liens (aujourd'hui amorcés par script).
- 🤖 Formulaire du site (espace annonceur) : envoyer explicitement `countries` (ciblage strict par pays).
- 👤 Sauvegarde nocturne testée (restauration d'essai), alerte de disponibilité, fermeture de la connexion root par mot de passe, suppression de `/home/deploy/import` (données personnelles) après usage, renouvellement du VPS avant le 01/12/2026.
- 🤖 Diagnostic « 403 sur tout » vu ce soir sur le test : le téléphone est probablement connecté avec un compte Firebase absent des données importées ; ajouter un journal clair sur ce cas.

## 4. Tâches et missions (gains) : mise en production
- 👤 Torox : changer l'adresse de retour (postback) des deux emplacements vers l'API de production ; cocher « envoyer un retour négatif en cas d'annulation » ; activer Torox en production après l'import ; poser `TOROX_PAYMENT_RECEIVED=true` après le premier paiement reçu.
- 🤖 Vérifier que Torox réutilise ou non le même `id` pour plusieurs événements d'une même offre (journal prévu).
- 📱 Faire une vraie tâche de bout en bout sur le test : clic, retour, gain « en attente », libération, ligne dans l'historique.
- 👤 Choix : garder les sondages bloqués (tirages au sort) — par défaut oui.
- 🤖 568 comptes sans date de création : bloqués 3 jours après la bascule ; décider d'une date de repli.

## 5. Régie Afrolook Ads
- 👤 Créer les premières campagnes réelles ; 📱 voir les annonces s'afficher selon le pays du profil.
- 🤖 Écran d'administration pour la version de l'application et les liens des stores (aujourd'hui : table `settings`, clés `app.version_code`, `app.version_code_official`).

## 6. Publication de la nouvelle version (stores)
1. 🤖 Gel du code : tous les points ci-dessus testés sur le serveur de test, suite de tests API verte, analyse de l'application sans erreur.
2. 🤖 Numéro de version/build (prochain : 2.0.17+268 d'après le journal), notes de version en français.
3. 👤 Pousser les dépôts (API, coordination) ; 🤖 déployer sur la production avec `deploy.sh`.
4. 👤 Import final des données réelles en production (export frais) puis bascule DNS/adresse de l'API dans l'application.
5. 🤖 Construire Android (AAB) et iOS ; 📱 essai sur plusieurs téléphones (anciens et récents).
6. 👤 Apple : vidéo de preuve des achats intégrés, fiche traduite, réponse à la revue 2.0.5 ; ne pas soumettre avant essai.
7. 👤 Soumission Google Play et App Store ; déploiement progressif (pourcentage) et surveillance des erreurs.
8. 🤖 Après diffusion : retirer la règle Storage temporaire `user_profile/`, éteindre les fonctions facturées migrées (`syncFollowsFromLegacy`…).

## 7. Après la migration (déjà décidé, pas commencé)
- Enregistreur vidéo dans l'application (60 s, puis Studio) : plan en 7 étapes, **non commencé**.
- Refonte Live Shopping, dialogue entre personnages et musique des templates (SlashAtlas), intégration MiniMax H3 (clé en attente).
- Quiz/Étude : classements et anti-triche ; Chroniques : affichage immédiat ; Musique : lecture en arrière-plan et pages de détails ; Appodeal (identifiants à fournir) ; maximisation des pubs.
- Photos d'AfroMode/AfroInfo ; décision sur l'envoi aux 1 444 anciens comptes.

## 7 bis. Lives et boutique : refonte « Live Shopping » (oubliée dans la première version de cette liste)
Décidée le 01/11/2026, fiche `connaissances/39_refonte_live_shopping.md` (dépôt de coordination). Modules actuels (`LiveController`, `ShopController`, cadeaux, Agora) déjà dans l'API et NON restructurés.
Pendant l'absence du propriétaire, je fais **seulement** ce qui ne demande pas ses décisions :
- 🤖 Plan par étapes livrables (1 Live Shopping physique + négociation · 2 produits numériques · 3 enchères · 4 billetterie · 5 Talk/PK et invités) avec la base de données à prévoir (`type_session`, produits épinglés, enchère en cours, séquestre).
- 🤖 Maquettes (propositions visuelles) de chaque écran : lancement depuis la boutique, studio des 4 formats, écran spectateur (produit épinglé, achat express, panier), panneau du vendeur, enchères, billetterie, suivi de commande et séquestre, litige/annulation.
- 🤖 Analyse de l'existant (lives, boutique, contenu payant, commissions) et propositions demandées : invités multiples, latence, jeux et objectifs de j'aime, modération.
- 👤 Les 14 questions sont rangées avec une réponse par défaut dans `QUESTIONS_POUR_LE_PROPRIETAIRE.md` (coordination). **Aucun code tant que le propriétaire n'a pas validé les maquettes** (règle qu'il a fixée) ; ce chantier n'est donc pas dans la mise à jour de stores en cours.

## 8. Documentation à remettre à jour
- 🤖 `docs/PROJET_MEMOIRE.md` sections 6 et 7 : plusieurs statuts datent d'avant le début du code de l'API (ex. « aucun code d'API n'existe ») ; à refaire d'après l'état réel.
