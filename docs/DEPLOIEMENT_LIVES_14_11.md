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

Migrations à jouer (le script `deploy-test.sh` le fait) : `2026_11_14_001000_live_no_camera` et `2026_11_14_002000_consultation_queue_and_slots`. Tâche planifiée nouvelle : `consultations:tick` (chaque minute : appels manqués, file, rendez-vous) ; contrôle : `php artisan schedule:list | grep consultations`.

## 4. Points connus, non traités

- Firestore reste utilisé pour le temps réel du live (chat, cœurs, effets, « écrit… ») ; passage à un WebSocket Laravel (Reverb) prévu plus tard.
- Les commentaires d'un live sans caméra ne sont vus par le serveur que par le signal de l'hôte (tous les 2 minutes, ou tout de suite pour un nouveau commentaire, au plus toutes les 20 s).
- Traductions des libellés du portefeuille `live.quiz_*` et des nouveaux textes du live sans caméra (8 langues) : à faire.
