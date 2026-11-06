# Niveau 3 des effets de visage (déformations en direct) : comparaison des voies

Date de la recherche : 06/11/2026. **Les chiffres viennent de pages de comparaison (en grande partie écrites par un concurrent, Banuba) : à confirmer auprès de chaque fournisseur avant toute décision.**

## Besoin
Gros yeux, bouche déformée, visage fin ou allongé, masques qui suivent les expressions, en direct dans la caméra et dans la vidéo enregistrée, sur Android puis iPhone. Application Flutter.

## Voie A : un kit du commerce

| Kit | Prix annoncé | Flutter | Taille ajoutée | Points d'attention |
|---|---|---|---|---|
| **DeepAR** | Gratuit jusqu'à 10 utilisateurs actifs (avec filigrane), puis environ 25 $/mois (1 000 utilisateurs), 100 $ (5 000), 500 $ (30 000), 1 000 $ (100 000) | Plugin **communautaire** (pas officiel) | non trouvée | Maquillage et beauté en bêta ; segmentation limitée (cheveux) |
| **Banuba Face AR** | Sur devis (selon plateformes, fonctions, utilisateurs actifs) ; essai gratuit 14 jours | Plugin **officiel** (`banuba_sdk`) | environ 15 à 25 Mo | Prix non publics ; informations tirées surtout de ses propres articles |
| **Snap Camera Kit** | Pas de grille publique trouvée ; certaines sources disent gratuit | Pas de SDK officiel Flutter ; plugin communautaire `camerakit_flutter` | non trouvée | Approbation de Snap ; **mention « Powered by Snap » obligatoire** ; les « lenses » ne s'utilisent que dans l'application via Camera Kit |

Avantages : déformations, maillage du visage, enregistrement avec effets, déjà fournis. Inconvénients : abonnement, dépendance à un tiers, application plus lourde, clé de licence à poser par le propriétaire (jamais dans un dépôt).

## Voie B : moteur maison
Caméra Android native (CameraX) + OpenGL + maillage du visage (MediaPipe Face Landmarker) + déformations par shaders + enregistrement du rendu. Gratuit, mais plusieurs semaines, impossible à vérifier sans téléphone, puis tout à refaire pour iPhone.

## Recommandation
Voie A, avec **Banuba** (plugin officiel, essai de 14 jours) ou **DeepAR** (grille publique, mais plugin communautaire et beauté en bêta). Commencer par l'essai gratuit pour juger la qualité sur un vrai téléphone avant de payer.

## À décider par le propriétaire
1. Voie A ou B.
2. Si A : quel fournisseur, et budget mensuel acceptable.
3. Obligation d'affichage du fournisseur acceptable (surtout Snap).

## Sources
- https://www.banuba.com/blog/best-flutter-ar-sdks-in-reviewed-for-production-apps
- https://www.snap.com/terms/snap-camera-kit
- https://www.banuba.com/blog/banuba-face-filter-sdk-vs-deepar-tested-head-to-head
- https://blog.laratranslate.com/best-ar-sdks-face-filters-virtual-try-on/
- https://www.banuba.com/blog/best-flutter-ar-sdks
