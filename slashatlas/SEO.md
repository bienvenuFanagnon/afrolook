# Référencement naturel (SEO) de SlashAtlas

Dernière mise à jour : 23 octobre 2026.

## Ce qui est en place (vérifié dans le code)
- **Technique** : pages statiques rapides (images webp, polices préchargées, cache), adresses propres avec `/` final, balise `canonical` sur chaque page, `hreflang` FR/EN/x-default, une seule `h1` par page, titres et descriptions uniques (contrôlés par `check.mjs` à chaque déploiement), `robots.txt`, texte alternatif sur les images.
- **Plans du site** : `/sitemap.xml` (toutes les commandes, catégories, guides, pages) et `/sitemap-communaute.xml` (commandes communautaires et profils de créateurs, généré à la demande), tous deux déclarés dans `robots.txt`, avec les liens `hreflang`.
- **Aperçus de partage** : Open Graph et Twitter sur toutes les pages ; l'opportunité « gagner de l'argent » (`/proposer/`) a sa propre image 1200 × 630 (`static/img/og-gagner-fr.jpg` et `-en.jpg`, régénérables avec `node scripts/og-earn.mjs`).
- **Données structurées (JSON-LD)** : `Organization` et `WebSite` (accueil), `BreadcrumbList` (commandes), `FAQPage` (catégories), `Article` (guides), `CreativeWork` + `BreadcrumbList` (commandes communautaires), `ProfilePage` + `ItemList` (créateurs), `HowTo` + `FAQPage` (page `/proposer/`).
- **Contenu** : 944 commandes, 45 catégories, 8 guides FR/EN (dont « Gagner de l'argent avec des commandes d'affiches IA » et « Créer une affiche publicitaire avec l'IA »).
- **Maillage interne** : lien « Mon espace créateur » dans le pied de page de toutes les pages, bloc d'annonce sur l'accueil, commandes liées dans chaque page de commande.
- **Pages communautaires** : le titre, la description et l'image sont dans le HTML envoyé (pas de JavaScript nécessaire), page inconnue = vraie erreur 404.

## Ce que seul le propriétaire peut faire (indispensable)
1. **Google Search Console** : ajouter la propriété `slashatlas.com`, vérifier le domaine (enregistrement DNS), puis envoyer `https://slashatlas.com/sitemap.xml` et `https://slashatlas.com/sitemap-communaute.xml`. C'est ce qui fait découvrir et suivre les pages.
2. **Bing Webmaster Tools** : même chose (importation possible depuis Search Console). Bing alimente aussi d'autres moteurs.
3. **Vérifier que `slashatlas.com` pointe bien vers le site** (le domaine est celui utilisé dans toutes les balises). Tant qu'il ne répond pas, Google ne verra rien.
4. **Liens entrants (backlinks)** : le facteur le plus déterminant, et il ne s'achète pas sans risque. Publier le lien sur : la chaîne WhatsApp, Facebook, Instagram, TikTok, YouTube (descriptions), LinkedIn, groupes de commerçants, annuaires et blogs d'entrepreneurs d'Afrique francophone, Product Hunt, communautés de designers.
5. **Profils de marque cohérents** : même nom « SlashAtlas » et même lien partout.
6. **Application Afrolook** : un lien vers SlashAtlas depuis le site et les stores d'Afrolook transmet de l'autorité.

## Plan de contenu (ce qui apporte vraiment du trafic)
Les recherches visées sont des besoins concrets, en français d'abord (Afrique de l'Ouest et centrale), puis en anglais. Un guide ou une page par intention :
- « affiche publicitaire gratuite », « créer une affiche avec l'IA », « modèle d'affiche salon de coiffure / restaurant / boutique / immobilier » ;
- « gagner de l'argent avec l'IA », « revenu complémentaire en ligne Afrique » ;
- « prompt affiche », « photo produit avec le téléphone », « affiche WhatsApp statut » ;
- une page par métier (coiffure, couture, pâtisserie, location de voitures…), chacune avec ses commandes.
Rythme conseillé : 1 à 2 guides par semaine, chacun avec une image de résultat réelle, des exemples avant/après et un lien vers la commande concernée.

## Mesure
- Search Console : impressions, clics, pages indexées, requêtes. Contrôler chaque semaine les pages « Découvertes, non indexées ».
- Les compteurs de l'administration (visiteurs, sources, pays) complètent la mesure.
- Objectif réaliste : les premières pages indexées en quelques jours, les premiers classements en 1 à 3 mois, la croissance durable en 6 à 12 mois. **Aucun site ne peut garantir un nombre de visites** : il dépend du contenu publié, des liens reçus et de la concurrence.

## À prévoir ensuite (non fait)
- Soumission instantanée des nouvelles pages (IndexNow) à chaque déploiement.
- Pages par métier et par pays (« affiche salon de coiffure Lomé », etc.).
- Avis et exemples de créations d'utilisateurs (avec leur accord) pour la preuve sociale.
- Version vidéo des guides (YouTube) avec lien vers chaque page.
