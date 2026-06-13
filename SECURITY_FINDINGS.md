# Rapport de sécurité — Afrolook (analyse, à traiter séparément)

> Ce document liste des points de sécurité identifiés lors de l'analyse du projet, **sans modification du code**.
> À traiter dans une session dédiée aux Cloud Functions / règles Firestore (hors scope de la refonte UI).

## Critique

### 1. Pas de `firestore.rules` / `storage.rules` dans le repo
Aucun fichier de règles trouvé localement, et `firebase.json` ne référence pas de section `firestore`/`storage`.
**Action** : vérifier dans la console Firebase si des règles sont déployées manuellement. Si oui, les rapatrier dans le repo pour versioning. Si non, c'est une urgence absolue (accès non contrôlé aux données).

### 2. Opérations monétaires gérées côté client
Fichiers concernés :
- `lib/services/retraitService.dart` (retraits)
- `lib/services/coin_gift_service.dart` (cadeaux de coins)
- `lib/services/pronostic_payment_service.dart` (paiements pronostics)
- `lib/services/abonnement_service.dart` (abonnements)

Ces services écrivent directement dans Firestore (solde, transactions) depuis l'app Flutter. Un client modifié/rooté peut potentiellement falsifier montants/IDs avant écriture si les règles Firestore ne valident pas strictement côté serveur.

**Action recommandée** : migrer la logique de débit/crédit vers des Cloud Functions `httpsCallable` qui valident côté serveur (solde suffisant, propriétaire de la transaction, etc.), et restreindre l'écriture directe sur les collections de soldes/transactions via les règles Firestore (`allow write: if false` sauf via Admin SDK).

### 3. Validation admin non vérifiée côté serveur
- `lib/services/retraitService.dart` : `validerRetrait(adminId)` / `annulerRetrait(adminId)` — `adminId` passé en paramètre par le client, sans vérification que l'appelant est admin.
- `lib/pages/pronostics/admin_pronostics_page.dart` (`crediterGagnants`) : même problème.

**Action recommandée** : utiliser les **Custom Claims Firebase Auth** (`isAdmin: true`) vérifiés côté Cloud Function et dans les règles Firestore (`request.auth.token.isAdmin == true`), au lieu de faire confiance à un ID transmis par le client.

## Élevé

### 4. `coin_gift_service.dart` — pas de vérification `senderId == auth.uid`
Avant de débiter `senderId`, rien ne garantit que l'utilisateur connecté est bien `senderId`. Un attaquant pourrait théoriquement débiter le compte d'un autre utilisateur.

**Action recommandée (faisable côté client sans toucher aux Cloud Functions existantes)** : ajouter une vérification `if (FirebaseAuth.instance.currentUser?.uid != senderId) throw Exception('Unauthorized')` avant tout débit. Ceci ne remplace pas une vraie protection serveur (règles Firestore / Cloud Function), mais réduit la surface d'erreur côté client en attendant.

### 5. Clé OneSignal API manipulée côté client (`authProvider.dart`)
La clé OneSignal est lue depuis Firestore et utilisée côté client pour envoyer des notifications.

**Action recommandée** : déplacer l'envoi de notifications vers une Cloud Function callable ; ne stocker la clé que côté serveur.

### 6. Tokens stockés en `SharedPreferences` non chiffré (`authProvider.dart`)
**Action recommandée (faisable côté client)** : remplacer par `flutter_secure_storage` pour les tokens sensibles. C'est un changement localisé et sans impact sur les modèles/requêtes.

## Moyen

### 7. Pas de rate limiting sur les opérations sensibles (retraits, cadeaux)
**Action recommandée** : à traiter côté Cloud Functions (compteurs par utilisateur/jour).

### 8. `print()` de données sensibles en prod (montants, IDs, transactions)
Fichiers : `retraitService.dart`, `pronostic_payment_service.dart`, etc.
**Action recommandée (faisable côté client, sans risque)** : remplacer les `print()` exposant des données sensibles par un logger conditionnel (désactivé en release), ou les supprimer. Sera fait au fil de la refonte module par module si tu valides.

---

## Ce qui sera fait dans le cadre de la refonte (validé par toi)
- Point 4 (vérification `senderId == auth.uid` côté client) : ajouté lors du traitement du module concerné, sans changer la signature des fonctions ni les requêtes existantes.
- Point 6 (stockage sécurisé des tokens) : ajouté lors du traitement du module Auth, en gardant la compatibilité (lecture de l'ancien stockage en fallback au premier lancement).
- Point 8 (print() sensibles) : nettoyé au fil de l'eau dans les fichiers touchés.

## Ce qui reste hors scope (nécessite Cloud Functions / Firestore Rules — décision à prendre séparément)
- Points 1, 2, 3, 5, 7.
