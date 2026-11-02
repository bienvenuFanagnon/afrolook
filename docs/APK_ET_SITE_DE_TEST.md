# APK de test et site web de test (02/11/2026)

## APK de test (à envoyer à ton équipe)
- Construit avec `flutter build apk --release --dart-define-from-file=staging_api.json --dart-define=TEST_BUILD=true` (signé avec la clé de TEST, voir `-PdebugSignRelease`).
- Il parle au **serveur de test** (`api-staging.afrolookmedia.com`) : les comptes sont ceux importés dans le test, rien n'est réel.
- Un **ruban orange « TEST »** s'affiche en haut à droite de tous les écrans. Il n'existe que dans cette version : l'application des boutiques n'a ni le ruban ni la possibilité de viser le serveur de test.
- Fichier : `afrolook_app_api/build/app/outputs/flutter-apk/app-release.apk` (je te donne le chemin exact quand la construction est finie).
- Les testeurs qui ont déjà l'application des boutiques doivent la **désinstaller** d'abord (signature différente). Connexion Google : l'empreinte de la clé de test doit être enregistrée dans Firebase (c'est déjà le cas sur ton téléphone de test ; sinon la connexion Google d'un autre téléphone échoue).

## Quoi faire tester
Lives (création, vente en direct, vocaux, prolongation payante), page Travail (tâches, dollars), Partage et gagne (profil, mission, lien à partager à partir d'une autre connexion que celle du créateur), administration (Régie, certifications, fiche d'un compte, réglages lives et ventes), thème clair et sombre, plusieurs langues.

## Site web de test
- Fichiers en place : `/var/www/site-staging` sur le serveur ; site « annonceur / diffuseur / administration de la régie » branché sur l'API de test.
- Adresse prévue : **`https://site-staging.afrolookmedia.com`**. Elle ne fonctionne qu'après deux actions de ta part :
  1. Cloudflare → DNS : ajouter un enregistrement **A** `site-staging` vers `185.170.12.250` (proxy activé, nuage orange), comme `api-staging`.
  2. Firebase → Authentication → Paramètres → Domaines autorisés : ajouter `site-staging.afrolookmedia.com` (sinon la connexion Google du site est refusée).
- Le site de test n'est jamais référencé (`X-Robots-Tag: noindex`).
- La refonte visuelle des espaces connectés et de l'administration (cartes aérées, pastilles de statut, états de focus, tableaux de bord) est ajoutée à la fin de `static/css/ads.css` de `site_api_test` ; à reporter dans `site/` le jour de la bascule avec le reste (`changements.diff` n'a pas été régénéré).
