# Mise en production, pas à pas (à suivre avec Claude, une étape à la fois)

Refait le 02/11/2026 (nuit). Plan de fond : `afrolook-coordination/connaissances/25_plan_de_bascule.md`. Ici : la version courte, dans l'ordre, avec qui fait quoi.
Légende : 👤 toi · 🤖 Claude · 📱 à essayer sur téléphone · ⛔ ne pas continuer si l'étape échoue.
Serveur : `ssh -i ~/.ssh/afrolook_vps root@185.170.12.250` (production : `/var/www/afrolook-api`, `api.afrolookmedia.com` ; test : `/var/www/afrolook-staging`, `api-staging.afrolookmedia.com`).

## Où on en est (02/11/2026, nuit)
- 🤖 Code de l'API : 1 118 tests passés ; application : analyse sans erreur, installée sur le téléphone de test.
- Clés de production déjà posées : FeexPay, nom du compartiment et adresse CDN, Agora, notifications FCM, signature et adresse des pubs.
- **Il manque encore en production : R2 (identifiant de compte + Access Key ID + Secret Access Key).** Cloudflare IA (Journal) et `TOROX_PAYMENT_RECEIVED` : plus tard. E-mails (SMTP) : à brancher.

## LA question qui décide du jour J
**La version de l'application qui parle à la nouvelle API (2.0.17, build 268 ou suivant) est-elle déjà publiée dans les boutiques, modules éteints dans Remote Config (`api_modules`) ?**
- **Oui** : on peut faire la nuit de bascule aujourd'hui (phase 4 ci-dessous).
- **Non** : aujourd'hui = phases 0 à 3 (code, clés, répétition). **L'import réel des soldes se fait le jour où l'application est disponible**, sinon les soldes importés seraient périmés : les gens continuent de dépenser leurs pièces dans l'ancienne application, qui écrit toujours dans Firestore.

## Phase 0 — Mettre le serveur de test à jour (👤 puis 🤖)
1. 👤 PC, dossier `afrolook-api` : `git add -A`, `git commit -m "…"`, `git push origin develop`.
2. 👤 Serveur : `cd /var/www/afrolook-staging` puis `sudo -u deploy -H env APP_DIR=/var/www/afrolook-staging APP_HOST=api-staging.afrolookmedia.com bash /var/www/afrolook-staging/deploy/deploy.sh develop` → « Déploiement OK ».
3. 👤 Serveur : `sudo -u deploy php /var/www/afrolook-staging/artisan counters:recount` (corrige les nombres d'abonnés).
4. 🤖 Je vérifie les routes et le bon fonctionnement. 📱 Tu essaies sur le téléphone (profil, partage, alertes équipe).

## Phase 1 — Clés de production (👤 sur le serveur, rien ne passe par Claude)
1. 👤 Cloudflare → R2 → Gérer les jetons API → jeton « Lecture et écriture » limité au compartiment `afrolook-media` ; noter l'identifiant de compte (page d'accueil de R2), l'Access Key ID et la Secret Access Key (affichée une seule fois).
2. 👤 Serveur : `sudo bash /var/www/afrolook-staging/deploy/poser-cles.sh` → **o** à la 1/5 (saisir les 3 valeurs, **Entrée** pour le compartiment et le CDN), **N** aux quatre autres.
3. 👤 Serveur : `sudo systemctl reload php8.3-fpm` (sinon l'ancienne configuration reste en mémoire).
4. 👤 Serveur : la liste de vérification des clés → tout « OK » ; 🤖 je la relis.
5. (non bloquant) 👤 E-mails : `sudo bash /var/www/afrolook-staging/deploy/poser-mail.sh` après avoir choisi un fournisseur SMTP (test : avec `APP_DIR=/var/www/afrolook-staging` devant ; production : sans).
⛔ `curl -s https://api.afrolookmedia.com/up` doit répondre 200.

## Phase 2 — Mettre le code en production (👤 + 🤖)
1. 👤 PC, `afrolook-api` : `git checkout main`, `git merge develop`, `git push origin main`, `git checkout develop`.
2. 👤 Serveur : `sudo -u deploy -H env APP_DIR=/var/www/afrolook-api APP_HOST=api.afrolookmedia.com bash /var/www/afrolook-api/deploy/deploy.sh main` → « Déploiement OK ».
3. 🤖 Je vérifie : migrations passées, `php artisan schedule:list`, `/v1/health`.
⛔ Pas de bascule tant que l'étape 3 n'est pas verte.

## Phase 3 — Répétition sur le serveur de TEST (👤 puis 🤖)
1. 👤 PC, dossier `afrolook-coordination/outils/export` : `gcloud auth application-default login`, `npm install firebase-admin`, puis `node export_ndjson.js --oui --dossier ./sortie` (lecture seule de Firestore, environ 25 000 lectures). **Ces fichiers contiennent des données personnelles : jamais dans Git, jamais dans un message ; à supprimer après l'import.**
2. 👤 PC : envoyer le dossier `sortie` sur le serveur dans `/home/deploy/import` (je te donne la commande `scp` et le `chown`).
3. 🤖 Serveur de test : `php artisan import:legacy users.ndjson follows.ndjson --wallets … --dry-run --report=rapport.json` (toutes les options listées dans la phase 4), puis lecture du rapport avec toi : comptes, soldes, abonnements, contenus.
⛔ Tout écart de soldes non expliqué : on ne continue pas.

## Phase 4 — La nuit de bascule (👤 + 🤖 ensemble) — seulement si l'application est publiée
1. 👤 Remote Config : `maintenance_paiements: true` (gel des achats, retraits et cadeaux).
2. 👤 Nouvel export complet (phase 3, étape 1) puis envoi sur le serveur de production.
3. 🤖 Import réel sur la **production**, avec rapprochement des soldes (écart zéro exigé) : `php artisan import:legacy users.ndjson follows.ndjson --wallets --paid-contents=<dossier> --friends=friends.ndjson --invitations=invitations.ndjson --blocks=blocks.ndjson --chronicles=chronicles.ndjson --journal=<dossier> --contes=<dossier> --etude=<dossier> --quiz=<dossier> --groups=groups.ndjson --shop=<dossier> --music=<dossier> --studio=<dossier> --share=<dossier> --channels=channels.ndjson --transactions=transactions.ndjson --withdrawals=withdrawals.ndjson --defis=defis.ndjson --services=user_services.ndjson --posts=posts.ndjson --comments=comments.ndjson --lives=lives.ndjson --conversations=chats.ndjson --keys=user_keys.ndjson --report=rapport_final.json` (`<dossier>` = le dossier de l'export). ⛔ Écart de soldes : on lève le gel et on reporte.
4. 🤖 `php artisan counters:recount`, `php artisan channels:score`, `php artisan import:certifications` (avec `certifies.ndjson`), vérification de santé (`/v1/health`).
5. 👤 **Équipe d'administration** : tu te connectes à l'application avec ton compte, puis 🤖 `php artisan staff:bootstrap <ton identifiant>` ; un second super-administrateur : `staff:bootstrap <identifiant> --additional` (obligatoire : un administrateur ne peut pas valider son propre profil). Droit `sellers.verify` pour la vérification des vendeurs.
6. 🤖 Images et fichiers : `php artisan media:migrate-legacy --dry-run` puis réel (reprenable ; à lancer après l'import).
7. 👤 **Cloudflare** : les routes `afrolookmedia.com/p/**`, `/share/**`, `/ads/api/*` et `/v1/*` pointent vers l'API.
8. 👤 **Torox** (seulement au moment voulu) : changer l'adresse de retour des deux emplacements vers `https://api.afrolookmedia.com/v1/offerwall/torox/postback`, cocher « retour négatif en cas d'annulation » ; 🤖 j'active Torox en production ; après le premier paiement reçu : `TOROX_PAYMENT_RECEIVED=true`.
9. 👤 Allumer les modules par vagues dans Remote Config (`api_modules`) : lectures, puis écritures simples, puis l'argent. Après chaque vague : 15 minutes d'observation (erreurs 5xx, paiement de test). 📱 Je te dis quoi tester.
10. 👤 Lever le gel des paiements.

## Phase 5 — Les 7 jours suivants (🤖)
- Rapport quotidien : comptes créés, pièces créditées et dépensées, commissions du jour, revenus de la régie, erreurs 5xx, échecs de paiement.
- Retour arrière possible tant que l'ancien système n'est pas éteint : un module qui pose problème repasse à `false` dans `api_modules`.
- Aucune suppression côté Firebase avant J+30. Ensuite : régénérer les clés exposées dans `AppData`, déployer les règles Firestore proposées, éteindre les anciennes fonctions.

## À décider ou à avoir avant la nuit de bascule
- La question « application publiée ? » ci-dessus ; date et heure du gel (quelques minutes si peu de monde, de nuit de préférence) ; prévenir les utilisateurs 3 jours avant (conseillé).
- Soumission aux boutiques si pas encore faite : numéro de version (2.0.17+268 ou suivant), AAB Android et iOS, vidéo de preuve des achats intégrés pour Apple, fiche traduite, réponse à la revue 2.0.5, déploiement progressif.
- Date de repli pour les 568 comptes sans date de création ; restauration d'essai de la sauvegarde ; renouvellement du VPS avant le 01/12/2026.
- Après la bascule : enregistreur vidéo (plan validé le 30/10, `connaissances/27_enregistreur_video.md`), traductions complètes des nouveaux écrans, SMTP si pas encore fait.
