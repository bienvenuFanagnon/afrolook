# Mise en production : Gold par pubs, Premium supprimé, Studio

> Rédigé le 07/11/2026. À suivre dans l'ordre. Rien n'est irréversible avant l'étape 3 (la migration Premium → Gold ne se défait pas).

## 0. Ce qui part en production

| Brique | Ce qui change pour les utilisateurs |
|---|---|
| **API** | Plan Premium non vendu (410), offres par pubs Premium / pièces / sans-pub retirées, **migration Premium → Gold**, passes de Gold gratuit, export, fonctions du Studio par pubs, plafond de pubs par jour 10 → 30, carte Commerce, vidéos épinglées, effets de temps, messages temporisés, mixage, suivi des e-mails, alertes de l'équipe |
| **Application** | Page Récompenses refaite, portes Gold du Studio (export, effets…), écran d'abonnement Gratuit / Gold, carte Commerce, épingler une vidéo, « Créer avec ce son », message à l'écran, mixage, écran admin « Suivi des e-mails » |
| **Site** | Barre « budget consommé » et bouton « Ajouter du budget » (annonceur), onglet « E-mails » (administration de la régie) |
| **Moteur d'effets de visage** | **Rien en production** : il n'est actif que dans les APK de test (`TEST_BUILD`). Il ajoute seulement du poids à l'application (modèles MediaPipe : ~20 Mo) |

## 1. Avant de déployer (propriétaire)

1. **Sauvegarde de la base** de production (obligatoire : la migration Premium → Gold ne se défait pas).
2. **Test d'abord sur le serveur de test** : `deploy.sh develop` sur staging, puis vérifier :
   - un compte Premium de test devient Gold (`select user_id, plan, expires_at from subscriptions`) ;
   - l'achat de Premium renvoie « Le plan Premium n'existe plus » ;
   - `GET /v1/rewards/state` contient le bloc `gold` ;
   - l'export sans Gold renvoie 402.
3. **eCPM** : saisir le vrai eCPM dans « Suivi de la page Travail » (sinon les passes valent 4 puis 6 pubs, l'export 3, les fonctions 3 / 4 / 6).
4. **Régie de pubs** : vérifier que le plafond de 30 pubs par jour est accepté par AdMob / Appodeal (validation côté serveur AdMob « SSV » active).

## 2. Ordre de déploiement

1. **API production** : `sudo -u deploy -H env APP_DIR=/var/www/afrolook-api APP_HOST=api.afrolookmedia.com bash /var/www/afrolook-api/deploy/deploy.sh main` (les migrations s'appliquent avec le déploiement : `reward_gold`, `feature_unlocks`, `post_commerce`, `post_commerce_clicks`, `posts.has_commerce`, `posts.studio_pins`, **`retire_premium_plan`**).
2. **Site** : `cd site && npm run build && cd .. && firebase deploy --only hosting:vitrine`, puis Ctrl+F5.
3. **Application** : fusionner `filtres-moteur` dans `main` (décision A17 ci-dessous), compiler la version, la publier. **Les anciennes versions de l'application** continuent de fonctionner (pas de rupture d'API) mais verront l'achat de Premium refusé et n'auront pas les portes Gold ; relever la version minimale quand la nouvelle est en ligne.

## 3. Après le déploiement (vérifications)

- [ ] Un abonné Premium existant voit « Gold » dans son abonnement jusqu'à la même date.
- [ ] Un compte gratuit voit la page Récompenses avec « Gold gratuit » et le nombre de pubs ; une passe donne 30 minutes de Gold.
- [ ] Exporter une création du Studio sans Gold demande de regarder des pubs ou de passer Gold ; publier reste libre.
- [ ] L'écran « Suivi des e-mails » (application et site) montre « Envoi réel actif » et les derniers e-mails.
- [ ] Lancer la commande de diagnostic des e-mails si un envoi échoue.

## 4. Décisions à prendre

- **A17 – Moteur d'effets dans la version de production** : fusionner tout `filtres-moteur` dans `main` (les effets restent invisibles aux utilisateurs, l'application grossit d'environ 20 Mo) ou n'y mettre que le Studio, les récompenses et le Gold ? *Recommandé : tout fusionner, les effets s'ouvrent ensuite par un réglage à distance (10 % puis tous).*
- Le texte de l'abonnement Premium reste dans quelques écrans secondaires (environ 700 mentions de « Premium » dans le code, sans effet : plus personne n'est Premium après la migration). Nettoyage progressif.

## 5. Ce qui n'est pas dans cette mise en production

Gestes de la main et bulle de pensée, maquillage, éléments du Studio réduits en pastille, effets de visage dans les lives, version iPhone du moteur : reportés (voir `docs/IDEES_MOTEUR_EFFETS.md`).
