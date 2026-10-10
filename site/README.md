# Site vitrine afrolookmedia.com

Site statique (FR + EN) : accueil, rémunération, Studio Cartes, fêtes nationales par pays (62 pays), contact, téléchargement,
règles, confidentialité, suppression de compte. Aucune dépendance à l'exécution ; le seul paquet npm (`qrcode`) sert à la génération.

## Fabriquer et vérifier
```bash
cd site
npm install            # une fois
node build.mjs         # écrit dist/ (141 pages, sitemap, robots, QR)
node check.mjs         # liens internes, ancres, titres et descriptions uniques, fichiers obligatoires
```

## Organisation
| Dossier | Rôle |
|---|---|
| `src/data.mjs` | les 26 styles de cartes, les 12 façons de gagner, les fêtes nationales (même table que l'app et le serveur) |
| `src/i18n.mjs` | tous les textes FR et EN |
| `src/config.json` | adresses : domaine, app web, boutiques, e-mail, formulaire |
| `src/rules.json` | texte des règles de l'application (page « Règles et conditions » et « Confidentialité ») |
| `build.mjs` | gabarits et génération des pages |
| `static/` | CSS, JS, polices (hébergées ici), images, `.well-known/` (assetlinks, AASA), `app-ads.txt` |

- **Cartes** : `static/img/card-*.webp` sont de vraies cartes produites par l'app (`flutter test test/card_site_assets_test.dart`
  avec `CARD_OUT=…`). Les refaire quand un style change.
- **Fêtes** : si on ajoute un pays, l'ajouter dans `src/data.mjs` ET dans `lib/pages/cards/card_events.dart` ET
  `functions/src/cards/cards.ts` (un test de l'app vérifie que ces deux dernières tables sont identiques).
- **Règles** : `src/rules.json` est extrait de `lib/pages/regles_confidentialite_page.dart`. Si la page de l'app change, régénérer le fichier.
- **Exemple de gains** (624 750 pièces ≈ 249 900 FCFA ≈ 381 €) : `src/config.json` → `example`. Taux : 10 FCFA = 25 pièces.

## Formulaire de contact
`contactMessage` (`functions/src/site/contact.ts`) : enregistre dans `ContactMessages` (collection fermée aux clients),
envoie un e-mail à l'équipe (`officiel.afrolook@gmail.com`, réponse directe à la personne), limite à 5 messages par heure et par
adresse IP, champ piège anti-robots. Les messages se lisent dans la console Firebase.

## Mise en ligne
Deux sites Firebase Hosting dans le projet `afrolooki` (cibles dans `.firebaserc`) :

| Cible | Site Firebase | Contenu |
|---|---|---|
| `vitrine` | `afrolooki` (domaine `afrolookmedia.com`) | ce site (`site/dist`) |
| `app` | `afrolook-app` | l'application web Flutter (`build/web`) |

### 0. Aperçu sans risque (rien ne change pour le public)
```bash
node build.mjs && node check.mjs
firebase hosting:channel:deploy apercu --only vitrine --expires 14d --project afrolooki
```

### 1. Mettre l'application web à sa nouvelle adresse (à faire AVANT de remplacer l'accueil)
1. `flutter build web` puis `firebase deploy --only hosting:app` → `https://afrolook-app.web.app`.
2. Console Firebase → **Authentication → Paramètres → Domaines autorisés** : ajouter `afrolook-app.web.app` (et `app.afrolookmedia.com`). Sans cela, la connexion échoue sur la nouvelle adresse.
3. Console Firebase → Hosting → site `afrolook-app` → **Ajouter un domaine personnalisé** `app.afrolookmedia.com`, puis créer l'enregistrement DNS demandé (CNAME dans Cloudflare).
4. Vérifier la connexion, un post, un live sur `https://app.afrolookmedia.com`. Si Google Sign-In ou un autre service limite les domaines (clés API, OAuth, Agora…), ajouter la nouvelle adresse.

### 2. Remplacer l'accueil
```bash
node build.mjs && node check.mjs
firebase deploy --only hosting:vitrine --project afrolooki
```
Les liens de partage `/share/**`, `/.well-known/assetlinks.json` (liens Android), `/.well-known/apple-app-site-association` (liens iOS) et `app-ads.txt`
continuent de fonctionner : ils sont inclus dans le site. **Après la bascule, ouvrir un lien `https://afrolookmedia.com/share/post/…` sur un téléphone avec l'app pour vérifier.**
Si Cloudflare met les pages en cache, purger le cache après la bascule.

### 3. Retour en arrière
`firebase hosting:clone afrolooki:<version précédente> afrolooki:live` (ou « Restaurer » dans la console, Hosting → historique).

## À faire plus tard
- Badges officiels Google Play / App Store à la place des boutons dessinés.
- Pages en anglais pour les règles et la confidentialité (le texte de l'app n'existe qu'en français).
- Outils de mesure (Search Console, statistiques) : à brancher quand le site sera en ligne.
