# Déploiement et essai des lives — 14/11/2026

Ce qui est livré dans cette version (API `main` + application `main`) : correction de l'écran noir des lives, live « sans caméra » (aperçu image ou vidéo en boucle, coupure sur inactivité), live « fantôme » réparé, « j'aime » au double toucher, pubs avec bouton « Fermer », logo du filigrane. Rien n'a été déployé en production : **serveur de test seulement**.

## 1. Déployer l'API sur le serveur de test — UNE SEULE COMMANDE

```bash
ssh root@185.170.12.250
cd /var/www/afrolook-staging && sudo -u deploy git pull --ff-only origin main && sudo bash deploy/deploy-test.sh
```

Les fois suivantes (le script se met à jour tout seul), une seule ligne suffit : `sudo bash /var/www/afrolook-staging/deploy/deploy-test.sh`.

Le script `deploy/deploy-test.sh` fait tout, dans l'ordre : code (branche `main`), dépendances, migrations (dont `2026_11_14_001000_live_no_camera` et les `2026_11_13_…` qui manqueraient), caches et droits, rechargement de PHP, pièces de test, puis des contrôles affichés un par un ([OK] / [ECHEC]) : l'API répond, la colonne `lives.no_camera` existe, l'arrêt automatique des lives est programmé, le cron du planificateur est en place. Il refuse de tourner sur la production. Autre branche : `sudo bash deploy/deploy-test.sh develop`.

Pièces de test en plus (déjà lancées par le script, mode billet à la demande) :

```bash
sudo bash /var/www/afrolook-staging/deploy/test-preparer.sh           # pièces de test à tous les comptes qui se connectent
sudo bash /var/www/afrolook-staging/deploy/test-preparer.sh billet    # + force le mode billet (gratuit du mois à 10 minutes)
sudo bash /var/www/afrolook-staging/deploy/test-preparer.sh gratuit   # remet le gratuit du mois
```

Le planificateur (`lives:auto-terminate`, toutes les 2 minutes) doit tourner : sans lui, un live sans caméra ne s'arrête pas pour inactivité. Contrôle : `sudo -u deploy php artisan schedule:list | grep lives`.

## 2. APK de test

Fichier : `build\app\outputs\flutter-apk\app-release.apk` (serveur de test, ruban TEST, même clé que les boutiques : s'installe par-dessus). Reconstruire : `.\scripts\build_test.ps1`.

Sur un téléphone où la version de **débogage** a été installée (celui du propriétaire) : désinstaller Afrolook d'abord (signature différente), puis installer l'APK.

## 3. Scénario d'essai avec les amis

1. Se connecter (pièces de test reçues). Ouvrir **Lives → créer un live**.
2. **Discussion avec caméra** : l'écran du live reste affiché (plus d'écran noir), menu, jeux (sondage), fin du live → bilan.
3. **Live sans caméra** : type discussion, quiz, conte ou marché → interrupteur « Sans caméra » → choisir une image, puis une vidéo de 15 s. Les spectateurs voient l'aperçu, le chat, les jeux, les cadeaux.
3 bis. **Salon audio** : même choix d'aperçu (image ou vidéo de 15 s en boucle) ; l'aperçu s'affiche derrière les voix. Le salon audio garde Agora (voix) et ne se coupe pas pour inactivité.
4. **Coupure sur inactivité** : ne rien faire pendant 8 minutes → bandeau d'avertissement chez l'hôte ; 10 minutes → le live s'arrête et le bilan s'affiche. Une question, un vote, un cadeau ou un commentaire relance le décompte.
5. **Conte et quiz** (erreur 422 corrigée) : créer, lancer un jeu, voter / répondre avec un second compte.
6. **Duel / défi** : inviter un second compte sur scène (deux téléphones).
7. **Live fantôme** : quitter l'application en plein live, la rouvrir, « Reprendre » : le live doit se rouvrir (plus de renvoi sur le bilan).
8. **Pubs** : 5 secondes, puis bouton « Fermer » (jamais de fermeture automatique) dans le fil, les chroniques et les vidéos verticales.
9. **Téléchargement d'une image** : le bandeau du bas porte la silhouette blanche du logo (plus de carré blanc).

## 3 bis. À essayer aussi (ajouts du 14/11, soir)

10. **« J'aime »** : toucher l'écran (même sans vidéo derrière) ou le cœur du bas : des cœurs montent tout de suite, le compteur monte, les autres personnes voient les cœurs aussi.
11. **Cadeaux** : panneau doux avec la ligne « Envoyés récemment » en haut (mémorisée sur le téléphone). L'hôte ne peut pas s'offrir un cadeau : il voit l'animation et un message d'aperçu. Un spectateur sans assez de pièces est mené à la recharge ; tout autre refus est expliqué.
12. **Quiz** : bouton « Historique » (colonne de droite) : questions déjà révélées avec bonne réponse, ta réponse, taux de réussite, podium. Jouer est gratuit pour le public ; la cagnotte vient de l'hôte (escrow), 50 / 30 / 20 % aux trois premiers.
13. **Épingles** : texte et image épinglés ; Menu → « Placement des épingles » (à gauche ou à droite, image à côté ou sous le texte). L'image ne passe plus sous la carte du quiz.
14. **Musique du live** : Menu → « Musique du live » (hôte) : une piste GRATUITE d'Afrolook jouée chez tous les spectateurs, sans Agora ; chacun règle son volume ; elle s'arrête quand on quitte le live.
15. **Consultation (expert)** : « Mon espace expert » (le bouton ne dit plus « Devenir expert » quand le profil existe) : bouton « Disponible maintenant », appels qui sonnent, file d'attente avec rang, chiffres et gains, rendez-vous (créneaux), historique.
16. **Consultation (patient)** : expert hors ligne → « Rendez-vous » ; expert occupé → file d'attente avec « Tu es 2e, attente estimée 15 min » ; notification « C'est ton tour ! » ; « Mes rendez-vous » (icône calendrier) ; rappel 15 minutes avant, puis l'appel arrive à l'heure.

17. **Duel / défi** : le résultat ne disparaît plus (gagnant, cadeaux et pièces reçues par chaque présentateur sur SON compte « pièces gagnées », 70 % des cadeaux ; aucun lot en plus pour le gagnant) ; croix pour le fermer ; bouton « Historique » (tous les jeux du live).
18. **Meilleurs donateurs du duel / du défi** : 🥇🥈🥉 avec pseudo et pièces sous chaque présentateur (et dans l'historique).
19. **Scène à plusieurs** (deux téléphones) : l'invité voit maintenant son propre aperçu (les vues vidéo sont recréées après le passage sur scène) et le chat ne recouvre plus la bande « Sur scène » ; **animation de voix** (bordure verte + 3 barres) sur la vignette de celui qui parle ; l'hôte a un bouton micro sur chaque invité (vidéo ou audio) : il coupe ou rétablit son micro pour tout le monde (rouge = coupé) ; l'invité est prévenu et ne peut pas le rétablir seul.

20. **Arrêter un jeu** : la croix de l'hôte sur la carte du jeu (ou Menu → « Arrêter et retirer le jeu ») arrête le jeu et le retire de l'écran de tout le monde ; il reste dans l'historique.
21. **Historique des jeux** : bouton dans le live (tous les jeux faits, détails : scores, votes, gains, meilleurs donateurs, gagnant du tirage, questions du quiz) ; pour l'hôte aussi dans le bilan d'un live terminé.
22. **Tirage au sort** : fonctionne même si l'application ne connaît pas les spectateurs (le serveur complète avec ceux qu'il connaît) ; sans personne, message clair ; gardé dans l'historique.
23. **Musique du live** : dans le choix de la musique, ▶ écoute un extrait (toi seul) avant de choisir ; une piste introuvable n'est jamais diffusée (message à l'hôte) ; la feuille « Musique du live » de l'hôte indique « Entendue par N spectateurs · M n'arrivent pas à la lire ». La lecture ne demande plus le focus audio (Agora le garde).

24. **Commandes : alertes et tableau de bord** : pastille rouge « Commandes » dans le live (commandes à valider + offres à répondre) ; pastille rouge « à traiter » sur « Mes commandes » (menu, liste des lives) ; « Mes commandes » s'ouvre sur l'onglet prioritaire (ventes à traiter, sinon achats à faire, sinon offres) ; tableau de bord en haut (à valider, en préparation, en livraison, litiges, offres, codes promo, achats en cours : chaque tuile ouvre la bonne liste) ; ventes : pseudo de l'acheteur, ancienneté, recherche par pseudo, filtres, pages de 30 (cent commandes et plus) ; achats : étapes Envoyée → Validée → Expédiée → Reçue et ce qu'il faut faire.
25. **Rappels par paliers (push)** : vendeur : commande sans réponse à 2 h, 24 h, 60 h (annulation automatique à 72 h), à expédier à 2 jours puis la veille de l'échéance ; acheteur : frais de livraison à accepter à 1 h puis 24 h, réception à confirmer à 3 jours puis la veille du versement ; offres : 1 h après chaque tour. Le serveur lance `shop-orders:sweep` toutes les heures.
26. **Code promo lié à un produit** (ou à tous) : à la création, « S'applique à » ; un code lié est refusé sur un autre article (`promo_other_article`).

27. **Vue d'ensemble de « Mes commandes »** : avant les onglets Achats / Ventes / Offres, un bandeau résume les trois catégories (à traiter, en cours, argent protégé ou reçu) ; chaque colonne ouvre son onglet. Deux vrais tableaux de bord : acheteur (argent protégé, « À faire maintenant », étapes, offres, dépenses, vendeurs habituels) et vendeur (à valider, en préparation, en livraison, offres, codes promo, argent, 14 jours, meilleurs produits).
28. **Notifications de commandes** : cloche en haut de « Mes commandes » (pastille rouge = non lues) → page qui regroupe les alertes de ventes, d'achats et d'offres ; toucher une ligne ouvre la bonne liste.
29. **Écran du live, sans superposition** : les blocs du haut (épingles, jeu ou étals, classement, vitrine, scène) sont rangés dans UNE colonne qui défile en entier ; dès qu'on a défilé, un petit résumé d'une ligne reste collé en haut (jeu en cours, vendeur en vente, personnes sur scène) ; un toucher remonte. Le bouton « Ouvrir ma vitrine » ne recouvre plus les étals.
30. **Règles par type de live** (`live_caps.dart`) : vente en direct et marché = vitrine, et seulement les jeux sans grande carte (objectif, tirage, questions, clips) ; duel / défi / conte / quiz = leur jeu et les aides légères ; discussion = tous les jeux. Dans un marché, la vitrine n'est gérée que par le vendeur dont c'est le tour (l'hôte n'est pas obligé d'être vendeur).
31. **Badge « Vendeur vérifié »** : bouclier VERT avec le mot « Vendeur vérifié » (icône seule en petit), à côté du pseudo dans les commandes et sur les étals du marché. Différent du badge officiel de l'application (coche habituelle).
32. **Marché** : une commande passée pendant un marché suit le même circuit qu'une vente en direct (séquestre, frais de livraison, code de livraison, versement automatique à 7 jours, même commission) ; le vendeur est celui de l'étal ; l'hôte du marché ne voit que les chiffres publics (jamais l'argent des vendeurs).

Migrations à jouer (le script `deploy-test.sh` le fait) : `2026_11_14_001000_live_no_camera`, `2026_11_14_002000_consultation_queue_and_slots` et `2026_11_14_003000_live_stage_host_mute` `2026_11_14_004000_live_games_dismissed`, `2026_11_14_005000_shop_more_reminders` et `2026_11_14_006000_shop_promo_article`. Tâche planifiée nouvelle : `consultations:tick` (chaque minute : appels manqués, file, rendez-vous) ; contrôle : `php artisan schedule:list | grep consultations`.

## 4. Points connus, non traités

- Lien de partage : dans l'APK de TEST il commence par `api-staging.afrolookmedia.com` (volontaire, il pointe vers le serveur de test) ; dans les versions des boutiques il commence par `afrolookmedia.com`.
- Firestore reste utilisé pour le temps réel du live (chat, cœurs, effets, « écrit… ») ; passage à un WebSocket Laravel (Reverb) prévu plus tard.
- Les commentaires d'un live sans caméra ne sont vus par le serveur que par le signal de l'hôte (tous les 2 minutes, ou tout de suite pour un nouveau commentaire, au plus toutes les 20 s).
- Traductions des libellés du portefeuille `live.quiz_*` et des nouveaux textes du live sans caméra (8 langues) : à faire.
