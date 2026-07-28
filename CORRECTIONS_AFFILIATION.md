# Corrections — Système Affiliation Marketing

> Fichier principal : `lib/pages/Marketing/affiliationMarketing.dart`
> Date : 2026-07-28

---

## CRITIQUE — Atomicité activation

**Problème** : `_activateOrRenewMarketing` exécute 4 `await` séparés (débit, transaction comptable, activation, commission). Un crash entre les étapes laisse l'utilisateur débité mais pas activé.

**Correction** : Regrouper débit + activation dans un seul `runTransaction`. Les commissions s'exécutent juste après.

```dart
await firestore.runTransaction((tx) async {
  final snap = await tx.get(userRef);
  final solde = (snap.data()?['votre_solde_principal'] ?? 0).toDouble();
  if (solde < subscriptionPrice) throw Exception('Solde insuffisant');
  tx.update(userRef, {
    'votre_solde_principal': FieldValue.increment(-subscriptionPrice),
    'marketingActivated': true,
    'marketingSubscriptionEndDate': endDate.millisecondsSinceEpoch,
    'lastMarketingActivationDate': now.millisecondsSinceEpoch,
  });
});
await _distributeCommissions(user); // après la transaction
```

---

## CRITIQUE — Encaissement marketing race condition multi-appareils

**Problème** : Le solde est lu depuis le cache local (`authProvider.loginUserData.solde_marketing`). Deux appareils simultanés peuvent déclencher deux encaissements du même solde.

**Correction** : Utiliser `runTransaction` avec lecture Firestore live + verrou `encaissement_marketing_en_cours`.

```dart
await firestore.runTransaction((tx) async {
  final snap = await tx.get(userRef);
  final solde = (snap.data()?['solde_marketing'] ?? 0.0).toDouble();
  final enCours = snap.data()?['encaissement_marketing_en_cours'] == true;
  if (enCours) throw Exception('Encaissement déjà en cours');
  if (solde < 5000) throw Exception('Minimum 5 000 FCFA requis');
  tx.update(userRef, {
    'solde_marketing': 0.0,
    'votre_solde_principal': FieldValue.increment(solde),
    'encaissement_marketing_en_cours': true,
  });
});
await userRef.update({'encaissement_marketing_en_cours': false});
await _createTransaction(...);
```

---

## CRITIQUE — Double commission sur réactivation

**Problème** : Si activation réussit (étape 3) mais la commission échoue (crash), une relance distribue une 2e commission au parrain.

**Correction** : Stocker `lastCommissionPaidAt` dans `Users`. Vérifier avant distribution que la commission n'a pas déjà été versée pour cette activation.

```dart
// Avant _distributeCommissions :
final userSnap = await userRef.get();
final lastActivation = userSnap.data()?['lastMarketingActivationDate'];
final lastCommission = userSnap.data()?['lastCommissionPaidAt'];
if (lastCommission != null && lastCommission == lastActivation) return; // déjà payé
// ... distribuer ...
await userRef.update({'lastCommissionPaidAt': lastActivation});
```

---

## HAUTE — Minimum encaissement : 7 000 → 5 000 FCFA

**Fichier** : `affiliationMarketing.dart` lignes ~1149 et message d'affichage

```dart
// Avant
final canEncash = solde >= 7000;
// Après
final canEncash = solde >= 5000;

// Message
'Minimum 5 000 FCFA pour encaisser' // était 7 000 FCFA
```

---

## HAUTE — Commission parrain : supprimer la restriction marketingActivated

**Problème actuel** : Le parrain ne reçoit sa commission QUE s'il a `marketingActivated == true`. Si le parrain n'a pas encore re-activé, il ne reçoit rien même si le filleul active.

**Nouvelle règle** : Le parrain reçoit TOUJOURS sa commission quand un filleul active, qu'il soit actif ou non. Par contre, les **statistiques et le bouton d'encaissement du filleul** sont verrouillés tant que son parrain n'est pas actif.

```dart
// Dans _distributeCommissions : supprimer la condition
// AVANT (à supprimer) :
if (parrainMarketingActivated) { ... }

// APRÈS : verser toujours si parrain existe
if (parrainQuery.docs.isNotEmpty) {
  await firestore.collection('Users').doc(parrainDoc.id).update({
    'solde_marketing': FieldValue.increment(commissionParrain),
    'total_gains_marketing': FieldValue.increment(commissionParrain),
    'commissionTotalParrainage': FieldValue.increment(commissionParrain),
  });
  await _sendCommissionNotification(...);
}
```

---

## HAUTE — Verrouiller stats + encaissement si parrain inactif

**Nouvelle règle** : Si le compte de l'utilisateur est actif mais que son parrain ne l'est pas (`parrainData?.marketingActivated != true`), les sections suivantes sont verrouillées avec un message d'action :
- Section statistiques (`_buildStatsSection`)
- Liste des filleuls actifs (`_buildSponsoredUsersSection`)
- Bouton d'encaissement

**Message à afficher** : "Votre parrain @{pseudo} doit re-activer son compte pour débloquer vos statistiques et l'encaissement."

```dart
// Condition à vérifier partout où les stats/encaissement sont affichés
final parrainActif = parrainData?.marketingActivated == true;

// Wrapper les sections avec un bloc "verrouillé" si !parrainActif
if (!parrainActif) _buildLockedSection(message: '...') else _buildStatsSection(...)
```

---

## HAUTE — Sections verrouillées si compte inactif (avec code parrainage visible)

**Règle** : Si `marketingActivated == false` :
- ✅ Code parrainage : **visible et copiable**
- 🔒 Section parrain : verrouillée
- 🔒 Statistiques : verrouillées
- 🔒 Liste filleuls : verrouillée
- 🔒 Bouton encaissement : verrouillé
- L'**action requise** est clairement indiquée sur chaque section verrouillée ("Activez votre compte marketing pour accéder à cette section")

**Implémentation** : Extraire `_buildReferralCodeSection` hors du bloc `if (hasParrain && isMarketingActive)` pour qu'il s'affiche toujours. Wrapper les autres sections dans un widget `_buildLockedOverlay`.

---

## HAUTE — Bug 0 jours affiché alors que compte actif

**Problème** : `difference.inDays` arrondit à l'entier inférieur. Si 23h59 restent, affiche 0.

**Correction** :
```dart
int _calculateDaysLeft(int endTimestamp) {
  final endDate = DateTime.fromMillisecondsSinceEpoch(endTimestamp);
  final now = DateTime.now();
  if (endDate.isBefore(now)) return 0;
  final difference = endDate.difference(now);
  // Arrondir au supérieur pour ne pas afficher 0 si abonnement encore actif
  return (difference.inHours / 24).ceil().clamp(1, 90);
}
```

---

## HAUTE — Vérification session Firebase Auth avant activation

**Règle** : L'activation nécessite une écriture Firestore authentifiée. Si `FirebaseAuth.instance.currentUser == null`, afficher un écran "Votre session a expiré, veuillez vous reconnecter" identique à la page Live, et rediriger vers la page de connexion.

**Implémentation** : Dans `_activateOrRenewMarketing` (et `_encashMarketingBalance`), vérifier en début de méthode :

```dart
import 'package:firebase_auth/firebase_auth.dart';

final firebaseUser = FirebaseAuth.instance.currentUser;
if (firebaseUser == null) {
  _showSessionExpiredDialog();
  return;
}

void _showSessionExpiredDialog() {
  showDialog(context: context, builder: (_) => AlertDialog(
    title: Text('Session expirée'),
    content: Text('Votre session a expiré. Veuillez vous reconnecter pour continuer.'),
    actions: [
      TextButton(onPressed: () { Navigator.pop(context); /* → page login */ }, child: Text('Se reconnecter')),
    ],
  ));
}
```

---

## MOYENNE — Ne pas afficher l'email des utilisateurs

**Fichier** : `affiliationMarketing.dart`

Deux endroits à corriger :

1. **Section parrain** (ligne ~584) :
```dart
// AVANT
subtitle: Text(parrain.email ?? '', style: ...),
// APRÈS : supprimer ou remplacer par le pays/statut
subtitle: Text(parrainData?.marketingActivated == true ? '✓ Compte actif' : 'Compte inactif', style: ...),
```

2. **Liste filleuls** (ligne ~927) :
```dart
// AVANT
subtitle: Text(user.email ?? '', style: ...),
// APRÈS : afficher le pays ou la date d'activation
subtitle: Text(user.userPays?.name ?? 'Afrique', style: ...),
```

---

## HAUTE — Guard appData.id avant force-unwrap

**Fichier** : `affiliationMarketing.dart` ligne ~1547

```dart
// AVANT
final appDataId = appData.id!; // crash si null

// APRÈS
final appDataId = appData.id;
if (appDataId == null) {
  printVm('⚠️ appData.id null, commission app ignorée');
  return;
}
```

---

## MOYENNE — Cooldown encaissement vues : type mismatch

**Fichier** : `lib/pages/user/mes_gains_post_page.dart`

Le cooldown cherche `ENCAISSEMENT_POST` mais l'écriture utilise `ENCAISSEMENT_VUES_POST`.

```dart
// Dans la query de vérification cooldown :
.where('type', isEqualTo: 'ENCAISSEMENT_VUES_POST') // était ENCAISSEMENT_POST
```

---

## MOYENNE — Parrain : bloquer changement après premier enregistrement

**Fichier** : `affiliationMarketing.dart` · `_addParrain()`

Vérifier que `code_parrain` est vide avant d'autoriser l'écriture :

```dart
if (currentUser.codeParrain != null && currentUser.codeParrain!.isNotEmpty) {
  _showErrorSnackbar('Vous avez déjà un parrain enregistré.');
  return;
}
```

---

## BASSE — Horaires retrait : déplacer dans le service

**Fichier** : `lib/services/retraitService.dart`

La vérification des horaires (lun-ven 8h-17h, sam 8h-14h) doit vivre dans `demanderRetrait()`, pas dans l'UI.

```dart
// Début de demanderRetrait() :
final now = DateTime.now();
final weekday = now.weekday; // 1=lun, 7=dim
final hour = now.hour;
bool isOpen = (weekday <= 5 && hour >= 8 && hour < 17) ||
              (weekday == 6 && hour >= 8 && hour < 14);
if (!isOpen) throw Exception('Service de retrait fermé. Disponible lun-ven 8h-17h, sam 8h-14h.');
```

---

## HAUTE — Modal "Solde insuffisant" avec montant pré-rempli et bouton Recharger

**Contexte** : Le dialogue `_showInsufficientBalanceDialog` existe déjà et redirige vers `DepositScreen`. Deux améliorations à apporter :

### 1. Pré-remplir le montant dans DepositScreen

Passer `defaultAmount: subscriptionPrice` pour que l'utilisateur arrive directement avec le montant manquant à recharger :

```dart
// Dans _showInsufficientBalanceDialog, action du bouton Recharger :
onPressed: () {
  Navigator.pop(ctx);
  Navigator.push(context, MaterialPageRoute(
    builder: (_) => DepositScreen(
      defaultAmount: subscriptionPrice, // 4 500 FCFA pré-rempli
    ),
  ));
},
```

### 2. Bouton d'encaissement marketing insuffisant → dialogue explicatif

Actuellement le bouton encaissement est simplement `onPressed: null` (grisé) sans explication. Si le solde marketing est entre 0 et 4 999 FCFA, rendre le bouton cliquable et afficher un dialogue :

```dart
// AVANT
onPressed: canEncash ? () => _encashMarketingBalance() : null,

// APRÈS
onPressed: () {
  if (!canEncash) {
    _showEncashMinimumDialog(solde);
    return;
  }
  _encashMarketingBalance();
},

void _showEncashMinimumDialog(double solde) {
  showDialog(context: context, builder: (ctx) => AlertDialog(
    backgroundColor: colors.surface,
    title: Text('Solde insuffisant', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold)),
    content: Text(
      'Votre solde marketing est de ${solde.toInt()} FCFA.\n\n'
      'Le minimum pour encaisser est de 5 000 FCFA.\n\n'
      'Continuez à parrainer pour augmenter votre solde.',
      style: TextStyle(color: colors.textSecondary, height: 1.5),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(ctx),
        child: Text('Fermer', style: TextStyle(color: colors.textSecondary)),
      ),
    ],
  ));
}
```

**Note** : Pour l'encaissement marketing, il n'y a pas de bouton "Recharger" car le solde marketing vient uniquement des commissions de parrainage — il ne peut pas être alimenté par un dépôt. Le message doit donc orienter vers le parrainage.

---

## Récapitulatif des champs Firestore à ajouter

| Champ | Collection | Type | Usage |
|---|---|---|---|
| `encaissement_marketing_en_cours` | `Users` | `bool` | Verrou anti multi-appareils |
| `lastCommissionPaidAt` | `Users` | `int` (timestamp) | Idempotence commission |
