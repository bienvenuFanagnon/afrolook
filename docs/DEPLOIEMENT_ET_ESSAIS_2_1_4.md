# Déploiement et essais de la version 2.1.4+280 (09/11/2026)

## A. Déployer, dans cet ordre

1. **API** (dans le dossier `afrolook-api`) : `git push origin main develop`
2. **Serveur de production** : `sudo -u deploy -H env APP_DIR=/var/www/afrolook-api APP_HOST=api.afrolookmedia.com bash /var/www/afrolook-api/deploy/deploy.sh main` (aucune migration ; une commande planifiée `studio:purge-previews` s'ajoute toute seule).
3. **Application** (dans le dossier de l'appli) : `git push origin main` (version `2.1.4+280`).
4. **Android** : `shorebird patch` pour les téléphones qui ont déjà la 2.1.3 (tout est du code Dart), et/ou un nouveau build pour Google Play.
5. **iPhone** : lancer le build Codemagic ; ne soumettre à Apple qu'après la réponse sur la 2.1.2.
6. **Avant de soumettre aux stores** : mettre à jour la déclaration de confidentialité (visionnage anonyme des vidéos, activité dans l'app : interactions, non liée à l'identité) sur App Store Connect et Google Play.
7. **Facultatif** : dans le tableau de bord Appodeal, désactiver PubMatic, MobileFuse, Ogury, TaurusX et Verve (retirés d'Android).

Tout ce qui est nouveau côté montage est **éteint par défaut** : `studio_single_pass` (rendu en une seule passe) n'est actif que si tu le règles, d'abord sur le serveur de test. Pour l'allumer sur le serveur de test :
`sudo -u deploy bash -c 'cd /var/www/afrolook-staging && php artisan tinker --execute="App\Models\Setting::updateOrCreate([\"key\"=>\"studio_single_pass\"],[\"value\"=>[\"enabled\"=>true],\"is_public\"=>true]);"'`
Pour l'éteindre : même commande avec `false`. Sous-interrupteur `"outro": true` (fin animée jointe sans réencoder, repli automatique) : à essayer seulement sur le serveur de test, après avoir validé `enabled` ; en production, seulement une fois validé sur téléphone.

## B. À tester, par ordre d'importance

**Après le déploiement du serveur (sans l'appli) :**
1. Une page d'accueil, un post, un live : tout marche comme avant.
2. Dans la base : `sudo -u deploy bash -c 'cd /var/www/afrolook-api && php artisan waves:refresh'` affiche « Vagues : N inscrites… ».

**Après le build, sur Android :**
3. Publier une vidéo : la ligne « Couverture » propose une image de la vidéo, un instant précis et une image de la galerie.
4. Après la publication, le post apparaît **en tête du fil**.
5. Choisir plusieurs images (2 à 5) : cadrage par image (pincer, glisser, double toucher), durée totale (7, 15, 30, 60 s), musique qui se cale, puis l'éditeur (pseudo ou `#canal` pour un post de canal).
6. Montage avec 5 images épinglées : taille, place, suppression de chacune ; pas de pseudo sur les images ajoutées.
7. « Voir le rendu exact » dans l'éditeur de montage (vidéo + musique).
8. **Live avec la beauté** (des extensions d'Agora ont été retirées).
9. Le menu « ⋯ » d'une publication : même contenu dans le fil, la page détail et les vidéos, avec « Diffusion ». La page détail d'une vidéo affiche « N interactions » et un seul bouton de menu.
10. Inscription : choix du pays dans la nouvelle liste, région et ville tapées à la main ; confirmation du code SMS (nouvelles fenêtres).
11. Équipe : valider un son artiste affiche une confirmation et la fiche disparaît de la liste.

**Rendu en une seule passe (facultatif, seulement si tu veux l'activer) :**
12. Allumer `studio_single_pass` = `{"enabled": true}` (avec `is_public` vrai), couper, accélérer, ajouter sous-titres et musique, publier ; comparer au même travail interrupteur éteint. En cas de souci : `{"enabled": false}`.

**Après le build, sur iPhone :**
13. Dans le journal Codemagic : la ligne « [allègement Agora] … » et la taille du `.ipa` (au dernier essai : 168 Mo de fichier, 299 Mo installés). Envoyer le nouveau `.ipa` pour mesure.
14. **Un live démarre sur iPhone** (si l'application plante au lancement : retirer le bloc « allègement Agora » du Podfile).
15. Les points 3 à 11 ci-dessus.

## C. Décisions qui restent
- Règle de dépassement de limite de produits d'une boutique (l'abonnement n'est plus vendu).
- Filtres de visage sur iPhone : valider `docs/FILTRES_VISAGE_IPHONE.md`.
- Réseaux publicitaires restants : revenus par réseau à fournir.
