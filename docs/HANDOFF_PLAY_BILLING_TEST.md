# Passation : test de Google Play Billing (achat de pièces) sur Android

Document pour la session Claude du bureau qui construit la version Android (Shorebird / appbundle).
Rien de confidentiel ici : les clés restent sur la machine de l'owner.

## Ce qui est déjà fait (côté serveur et stores)

- **Produits Play Console** (consommables, actifs, 174 pays), package `com.afrotok.afrotok`, option d'achat `achat` :

  | ID produit | Pièces | Prix de base (USD) |
  |---|---|---|
  | `com.afrotok.afrotok.coins1000` | 1 000 | 1,49 $ |
  | `com.afrotok.afrotok.coins4000` | 4 000 | 5,99 $ |
  | `com.afrotok.afrotok.coins10000` | 10 000 | 14,99 $ |

  Les prix sont majorés (≈ prix Mobile Money ÷ 0,7) : la commission du store est payée par l'acheteur.
- **App Store Connect** : les 3 produits Apple sont passés aux mêmes prix (déjà appliqués par l'API).
- **Cloud Function `verifyGooglePlayPurchase`** déployée (projet Firebase `afrolooki`, us-central1). Secret `GOOGLE_PLAY_SERVICE_ACCOUNT` enregistré. Elle vérifie l'achat auprès de Google, crédite les pièces (idempotent, collection `GooglePlayPurchases`), puis confirme (acknowledge) l'achat.
- **Compte de service Play** : `play-publisher@street-rumble-afrolook.iam.gserviceaccount.com`, accès à l'app vérifié (lecture des produits OK).
- Le code Flutter a été analysé (`flutter analyze lib`) : aucune erreur de compilation.

## Ce que fait l'app (code déjà sur la branche `refonte_claude`)

- Android + pays africain : bascule Google Play / Mobile Money.
- Android + pays hors Afrique ou inconnu : Google Play uniquement (`lib/pages/coins/play_coin_store_view.dart`).
- iOS : App Store uniquement (inchangé).
- Service : `lib/services/google_play_iap_service.dart` (démarré dans `homeScreen.dart`).
- Version : `pubspec.yaml` = `2.0.6+249`. Le versionCode Android actuel en ligne est 248, donc 249 est bien supérieur.

## Ce qu'il reste à faire une fois le build terminé

1. **Publier le `.aab` sur la piste Test interne** de Play Console (Tests → Test interne → Créer une version).
   - Attention : un build **Shorebird patch** ne suffit pas, car l'achat intégré demande un binaire natif avec la bibliothèque de facturation. Il faut une vraie **release** (`shorebird release android`), pas un `patch`.
   - Le bundle doit être signé avec la clé d'envoi de l'owner (pas la clé de test `afrolook-test.jks`).
2. Ajouter le Gmail de l'owner comme **testeur de la piste** et dans **Paramètres → Test de licence** (achats gratuits).
3. Installer depuis le lien de test interne (jamais par APK direct, sinon la facturation est refusée).
4. **Scénario de test** : Recharger des pièces → pack 1 000 → achat de test → les pièces doivent être créditées en quelques secondes. Vérifier ensuite dans Firestore :
   - `GooglePlayPurchases/{sha256(token)}` créé ;
   - le solde de pièces du compte augmenté de 1 000 ;
   - une ligne `TransactionSoldes` avec `methode_paiement: "google_play"`.
5. Tester aussi : compte hors Afrique (ou pays inconnu) → Google Play seul ; compte africain → bascule des deux modes ; double clic / relance de l'app pendant l'achat → pas de crédit en double.

## En cas de problème

- Message « produit introuvable » : l'app n'est pas installée depuis la piste de test, ou le compte n'est pas testeur.
- Erreur serveur `verifyGooglePlayPurchase` : consulter les logs de la fonction (Firebase → Functions) ; le compte de service doit garder les droits « Consulter les informations financières » et « Gérer les commandes et abonnements » dans Play Console.
- Compte de service : le fichier JSON de clé est sur le PC de l'owner (`D:\Personnel\Downloads\street-rumble-afrolook-669a01a69e52.json`) ; ne jamais le committer.

## Rappels

- Remettre `freeSessions` à 3 dans la config Quiz si ce n'est pas déjà fait.
- Après validation du test, la mise à jour obligatoire se règle avec `AppData.app_version_code` (249).
