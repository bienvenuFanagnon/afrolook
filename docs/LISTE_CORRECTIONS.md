# Liste des corrections demandées — ce qui est fait, ce qui reste

Mise à jour : 02/11/2026. Légende : ✅ fait et testé côté API / analysé côté application · 📱 à vérifier sur ton téléphone (staging) · ⏳ reste à faire · 🔑 action de ta part.

> L'application n'a pas encore été lancée sur téléphone avec toutes ces modifications : « fait » côté application = le code compile (`dart analyze` sans erreur), pas encore vu à l'écran. L'API, elle, est couverte par 1 088+ tests automatiques.

## 1. Pages Travail et Partage

| Demande | État |
|---|---|
| Page Travail trop chargée, moins de texte, infos repliables, 2 boutons en haut | ✅ 📱 |
| « Bientôt disponible » / « dans quelques jours » à corriger | ✅ 📱 |
| Vidéo tutoriel une seule fois dans les fils | ✅ 📱 |
| FCFA sous les pièces sur les tâches des partenaires | ✅ 📱 |
| **Dollar à côté du FCFA** (ex. « ≈ 40 F · ≈ $0.016 ») sur la page des tâches | ✅ 📱 (fait aujourd'hui) |
| Consignes des tâches partenaires traduites | ✅ (traduction automatique côté serveur) 📱 |
| « Comment ça marche ? / Lire plus » sur la page Travail | ✅ 📱 |
| Une publicité avant la liste des tâches, pas à chaque tâche | ✅ 📱 |
| Consignes complètes visibles avant de commencer une tâche | ✅ 📱 |
| Page des tâches qui ne chargeait pas | ✅ (chargement après le premier affichage) 📱 |

## 2. Lives et vente en direct (Live Shopping)

| Demande | État |
|---|---|
| Création d'un live de vente depuis la boutique et depuis la page de création de live | ✅ 📱 |
| Menu : « Boutique » et « Mes commandes » à la place de « Mon journal » / « Découverte » | ✅ 📱 |
| Page de création de live en thème clair / sombre | ✅ 📱 |
| Image de couverture du live dans les fils (sinon photo de l'hôte) | ✅ 📱 |
| Doublons « 4 lives » avec la même image | ✅ 📱 |
| Heure décalée d'une heure (« il y a 1 h ») | ✅ pour les nouvelles données (les anciennes données de test gardent le décalage) |
| Infos de livraison et détail du produit dans le live | ✅ 📱 |
| Vitrine « très impressionnante » (photos, stock, vente flash, minuteur) | ✅ 📱 |
| Produits épinglés qui défilent tout seuls | ✅ 📱 |
| L'hôte change les produits épinglés pendant le live (« Gérer ma vitrine ») | ✅ 📱 |
| Gestion du stock, alertes de stock, stock visible de tous | ✅ (API testée) 📱 |
| Bouton « Arrêter » rangé dans un menu (« Terminer le live ») | ✅ 📱 |
| Bouton « Ma boutique » sur la page de vente | ✅ 📱 |
| Historique des lives de vente avec statistiques de ventes | ✅ 📱 |
| Message « ton argent est protégé » à la place de « bloqué » | ✅ 📱 |
| Solde insuffisant → bouton « Recharger X F et commander », la commande repart seule après la recharge | ✅ (fait aujourd'hui) 📱 |
| Pourcentage prélevé sur la vente | ✅ 10 % par défaut, **réglable par l'équipe** (voir §5) |
| Code de livraison à 4 chiffres, avis acheteur, vendeur fiable, codes promo, rappels | ✅ API testée · ⏳ écrans « codes promo » et « étoiles du vendeur » à finir |
| Produits numériques, enchères, billetterie, replay, partenaires de livraison | ⏳ mis de côté comme tu l'as décidé |

## 3. Administration

| Demande | État |
|---|---|
| Hub d'administration dédié à la vente en direct (commandes, litiges, statistiques) | ✅ 📱 |
| Certifications conservées, gérables (ajouter / retirer) | ✅ 📱 |
| Les fonctions d'administration continuent de marcher (rôle admin reconnu) | ✅ 📱 |
| Missions manquantes sur le site de test | ✅ |
| Site de test avec des campagnes | ✅ |
| Équipe d'administration (comptes staff) à créer | ⏳ 🔑 à faire avant la mise en service |

## 4. Données et import

| Demande | État |
|---|---|
| Certification perdue à l'export | ✅ corrigé dans l'outil d'export · 🔑 **refaire l'export des utilisateurs avant l'import final** |
| Comptes officiels, partages importés | ✅ |

## 5. Limites de durée et de nombre de lives (demandé aujourd'hui)

| Règle | État |
|---|---|
| Durée maximale : 30 min (60 min pour l'équipe), fin automatique du live | ✅ existait déjà dans l'API |
| 5 lives gratuits par mois ; illimité avec Premium, Gold ou équipe | ✅ **appliqué par le serveur** (avant, seulement dans l'application) |
| Le jeton vidéo (Agora) s'arrête à la fin prévue du live → plus de facturation si quelqu'un reste connecté | ✅ **nouveau** |
| **Payer pour continuer** : à 2 minutes de la fin, l'hôte peut prolonger de 60 min pour 100 FCFA (250 pièces), 3 fois au plus par live | ✅ **nouveau** · 📱 |
| Réglages (quota gratuit, durée, prix, nombre de prolongations, % de commission) modifiables par l'équipe | ✅ côté API (réglage `live_limits` et `live_shop`) · ⏳ écran d'administration pour les modifier |

## 6. Vocaux des spectateurs (demandé aujourd'hui)

| Règle | État |
|---|---|
| Le spectateur envoie un vocal de 30 s au plus ; 3 vocaux par spectateur et par live | ✅ API testée · 📱 |
| Fichier privé : seul l'hôte peut l'écouter (lien temporaire) | ✅ |
| L'hôte : liste, écoute, ignorer, signaler (bloque l'auteur), couper l'option | ✅ 📱 (menu du live → « Vocaux des spectateurs ») |
| Effacement automatique 7 jours après la fin du live | ✅ |

## 7. Ce qui reste (par ordre)

1. 🔑 Pousser l'API (`afrolook-api`, branche `develop`) puis la déployer sur le site de test : **3 nouvelles migrations** (confiance et promos, limites de lives, vocaux).
2. 📱 Test sur téléphone avec deux comptes (vendeur + acheteur) : commande, code de livraison, avis, recharge, prolongation de live, vocal.
3. ⏳ Écrans manquants : codes promo (vendeur), étoiles / « vendeur fiable » dans la fiche produit, champ code promo à l'achat, écran d'administration des réglages (commission, durée, prix de prolongation).
4. ⏳ Traductions des nouveaux écrans dans les 7 autres langues (aujourd'hui : français + anglais).
5. 🔑 Clés de production : Cloudflare R2 (bucket de production), Agora, FCM, clé IA (Workers AI), régie publicitaire.
6. 🔑 Refaire l'export des utilisateurs (certifications), puis import final avec `--share=`.
7. 🔑 Création de l'équipe d'administration sur la production, bascule Torox, envoi aux stores (version 2.0.17+268).
8. ⏳ Visualiser la base PostgreSQL (DBeaver) : étape 1 donnée, la suite à faire ensemble.
