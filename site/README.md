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
`contactMessage` (`functions/src/site/contact.ts`) : enregistre dans `ContactMessages` (collection fermée aux clients), puis envoie
l'e-mail à `contact@afrolookmedia.com` ET à `officiel.afrolook@gmail.com` (secours) en un seul envoi, réponse directe à la personne.
Le résultat de l'envoi est noté sur le message (`mailStatus` : `sent`, `partial`, `backup_only`, `failed`, avec `mailDetail`).
Limite : 5 messages par heure et par adresse IP, champ piège anti-robots. Les messages se lisent dans la console Firebase.
Expéditeur : le serveur d'envoi LWS n'accepte que l'adresse du compte SMTP (`SMTP_USER`) ; `contact@afrolookmedia.com` est refusé comme expéditeur.

## Mise en ligne : un seul site, un seul domaine
Un seul site Firebase Hosting (`afrolooki`, cible `vitrine`, domaine `afrolookmedia.com`) sert tout :
- `/` et toutes les pages du site : `site/dist` ;
- `/app/` : l'application web Flutter (connexion, inscription, fil…), même domaine donc mêmes domaines autorisés Firebase Auth ;
- `/share/**` : fonction `sharePostLink` ; `/.well-known/*` et `app-ads.txt` à la racine ;
- anciennes adresses : `/#/…` (ancienne application à la racine) est redirigé vers `/app/#/…` par un petit script de l'accueil ;
  `/post/**` et `/feexpay-callback` redirigent vers `/app/` ; `/flutter_service_worker.js` à la racine est un nettoyeur qui retire
  l'ancien service worker chez les visiteurs de retour.

### Mettre à jour le site ET l'application web
```bash
flutter build web --release --base-href /app/ --no-tree-shake-icons --no-wasm-dry-run   # à la racine du dépôt
cd site && node build.mjs && node with-app.mjs && node check.mjs
firebase hosting:channel:deploy apercu --only vitrine --expires 14d --project afrolooki   # aperçu sans risque
firebase deploy --only hosting:vitrine --project afrolooki                               # mise en ligne
```
Sans changement de l'application, `node build.mjs` seul vide `dist/` : toujours enchaîner `with-app.mjs`, sinon `/app/` disparaît.
Les liens du site vers l'application web pointent vers `/app/` (`appWebUrl` dans `src/config.json`) ; les e-mails de l'app aussi (`APP_WEB_URL_AFRO`).
Si Cloudflare met des pages en cache, purger le cache après la mise en ligne.

### Retour en arrière
`firebase hosting:clone afrolooki:<version précédente> afrolooki:live` (ou « Restaurer » dans la console, Hosting → historique).
Version en ligne avant la bascule du 10 octobre 2026 : `4d5aa6716eb6399a` (ancienne application à la racine).

## À faire plus tard
- Badges officiels Google Play / App Store à la place des boutons dessinés.
- Pages en anglais pour les règles et la confidentialité (le texte de l'app n'existe qu'en français).
- Outils de mesure (Search Console, statistiques) : à brancher quand le site sera en ligne.
