# Verrouillage de la collection `Advertisements` (Afrolook Ads, étape 3)

**État (30/10/2026) :** l'application Flutter ne **modifie plus** aucun compteur de pub (vues, clics) : tout passe par `AdsEngineService`
(`lib/services/ads_engine_service.dart`) et le moteur (`adsServe` → `adsEvent` / `adsGo`). **Les règles Firestore ne sont PAS encore verrouillées** :
tant qu'elles ne le sont pas, une application modifiée ou une ancienne version peut encore écrire les compteurs.

## Pourquoi on ne peut pas verrouiller tout de suite
Les anciennes versions de l'application écrivent directement les compteurs. Une règle qui l'interdit ne casse rien d'autre (les écritures sont
rejetées, les erreurs sont attrapées) mais **leurs vues et clics cessent de compter** jusqu'à la mise à jour de l'utilisateur.
**La mise à jour obligatoire existe déjà** (précisé par le propriétaire, 30/10) : `AuthProvider.checkAppVersionAndProceed` compare le code de version de l'application
(`app_version_code`, défini dans `lib/providers/authProvider.dart`, **265 au moment de la rédaction alors que `pubspec.yaml` est en 2.0.17+266 : le monter à la valeur du build publié**)
au `app_version_code` du document Firestore `AppDefaultData` (modifiable dans l'écran admin « Version actuelle / Version officielle »). Si la valeur en ligne est plus grande, un **modal bloquant**
(`_showUpdateModal`, renvoi vers Play Store / App Store) s'affiche. Il est ignoré en debug, sur le web et pendant une revue des stores (`googleVerification` / `appleVerification`).
Seules les versions qui contiennent déjà ce modal peuvent être bloquées ; les plus anciennes ne le seront jamais (elles perdront seulement le comptage de leurs vues).

## Procédure
1. Dans `authProvider.dart`, mettre `app_version_code` au numéro de build à publier ; publier la nouvelle version (Android + iPhone) qui contient `AdsEngineService`.
2. Une fois la version disponible dans les deux stores, **monter `app_version_code` dans `AppDefaultData`** (écran admin) à ce numéro : les versions anciennes affichent le modal de mise à jour obligatoire.
3. Ajouter la règle ci-dessous **et** ajouter `'Advertisements'` aux deux listes d'exclusion de la règle générale `match /{collection}/{docId}` (sinon elle autorise encore tout) ;
   tester avec l'émulateur (création avec compteurs à 0 : acceptée ; mise à jour d'un compteur par un utilisateur : refusée ; par un administrateur : acceptée).
4. Déployer : `firebase deploy --only firestore:rules --project afrolooki`.

## Règle à ajouter (non active)
```
match /Advertisements/{adId} {
  allow read: if isAuth();
  // un annonceur crée son annonce avec des compteurs à zéro, jamais « réseau » ni avec un budget (ces champs sont posés par le serveur)
  allow create: if isAuth()
      && request.resource.data.get('views', 0) == 0 && request.resource.data.get('clicks', 0) == 0
      && request.resource.data.get('uniqueViews', 0) == 0 && request.resource.data.get('uniqueClicks', 0) == 0
      && request.resource.data.get('viewersIds', []).size() == 0 && request.resource.data.get('clickersIds', []).size() == 0
      && request.resource.data.get('network', false) == false && !('budgetViews' in request.resource.data);
  // personne (sauf un administrateur) ne modifie les compteurs ni les champs de livraison : seuls les serveurs le font
  allow update: if isAuth()
      && (isAdmin() || !request.resource.data.diff(resource.data).affectedKeys()
          .hasAny(['views', 'clicks', 'uniqueViews', 'uniqueClicks', 'viewersIds', 'clickersIds', 'dailyStats', 'placements', 'network', 'budgetViews']));
  allow delete: if isAuth();
}
```
Reste hors périmètre (à traiter ensuite) : un utilisateur peut encore passer lui-même `status` à `active` ou prolonger `endDate` sur sa propre annonce ;
à verrouiller quand tous les parcours de paiement des pubs passeront par une fonction serveur.

## Ce que le serveur fait déjà pour l'application (déployé après « oui, déploie »)
- `adsServe` (pub `afrolook`) exige App Check **et** le jeton d'identité de l'utilisateur ; le visiteur compté est l'utilisateur (`vid` = uid), pas l'appareil.
  Paramètre `ad` = annonce choisie par l'application : vérifiée active, non masquée, dans son budget ; le jeton de comptage est signé pour cette annonce.
- `adsEvent` : `e: "view"` (durée visible comparée à l'heure d'émission du jeton, 3 vues par annonce et par utilisateur et par jour) et `e: "click"`
  (réservé à l'application, pour les actions internes sans lien ; un clic par jeton). Les autres plateformes cliquent toujours via `adsGo`.
